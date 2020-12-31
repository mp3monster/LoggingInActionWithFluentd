#
# Copyright 2020- Phil Wilkins
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'
require "fluent/plugin/input"
require "redis"

module Fluent
  module Plugin
    # Input plugin for Fluentd using Redis Lists
    # all of our methods include the use of Trace - whilst typically this would be overkill, it does
    # help with observing how the plugin is working
    # @see https://blog.mp3monster.org/publication-contributions/fluentd-unified-logging-with/
    #todo: For candidate functional improvements see the readme-final.md file    
    class RedislistInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("redislist", self)
      helpers :thread

      # :section: configuration parameters
      # the configuration parameter description is picked up and processed using the Fluentd CLI tool
      # for generating documentation
      desc "specifies the port to connect to Redis with, will default to 6379 if not specified"
      config_param :port, :integer, default: 6379, secret: false, alias: :portNo
      desc "Defines the host address for Redis, if not defined 127.0.0.1"
      config_param :hostaddr, :string, default: "127.0.0.1", secret: false
      desc "Defines the number of reconnection attempts before giving up on connecting to the Redis server"
      config_param :reconnect_attempts, :integer, default: 2
      desc "Defines the number of seconds before timing out a connection to the Redis server"
      config_param :connection_timeout, :integer, default: 5
      desc "Defines the name of the list to be used in Redis, by default this is Fluentd"
      config_param :listname, :string, default: "fluentd"
      desc "The frequency in seconds between checking in with Redis for log events"
      config_param :run_interval, :integer, default: 1
      desc "determine whether or not to set the log event time to the original time it occured, rather than the time when the event was retrieved from Redis"
      config_param :use_original_time, :bool, default:false
      desc "determine whether or not to set the log event tag to the original tag used when the event was stored in Redis, rather than the tag when the event was retrieved from Redis"
      config_param :use_original_tag, :bool, default:false
      desc "Indicates whether the original event timestamp should be included into the log event record"
      config_param :add_original_time, :bool, default:true
      desc "Indicates whether the original event tag should be included into the log event record"
      config_param :add_original_tag, :bool, default:true
      desc "Defines the attribute name to be used in the log event record if original event tag should be included"
      config_param :add_original_tag_name, :string, default: "originalTag"
      desc "Defines the attribute name to be used in the log event record if original event timestamp should be included"
      config_param :add_original_time_name, :string, default: "originalTime"
      desc "Sets the tag if not defined to match the plugin type"
      config_param :tag, :string, default: @type

      # provide the direction label as a constant as it is used in several places
      # direction relates which end of the Redis List is consumed from
      # creating a LIFO (Last In First Out) or FIFO (First in First Out) behavior
      directionLabel = "direction"
      # defined expected value for direction to be FIFO. This is our default
      FIFOdirection = "FIFO"
      # defined expected value for direction to be LIFO
      LIFOdirection = "LIFO"

      desc "Process as FIFO or as LIFO"
      config_param :direction, :string, default: "FIFO"    
    
      # the label used to identify the tag part of a log event when added to Redis
      TagAttributeLabel = "tag"
      # the label used to identify the time part of a log event when added to Redis
      TimeAttributeLabel = "time"
      # the label used to identify the actual log event record part of a log event when added to Redis
      RecordAttributeLabel = "record"      

      # this is the loop controller to continue the process going until
      # a shutdown is triggered
      keep_running = true

      # separater on a JSON structure
      SEPARATOR = ','

      # use the Redis connection as a member variable so we don't need to keep constructing connections
      # each time we need to perform an operation
      @redis

      # record as to whether we're operating a FIFO behaviour for
      # where the list is popped from
      @fifo = true

      # :section: Utilities

      # look at the configuration determine which way should the list be used LIFO or FIFO
      # if in doubt we adopt the FIFO behavior. If the configuration isn't set we default to FIFO
      # if a value is provided we dont recognize, then default to FIFO but report a warning
      # @param conf [Object] configuration data provided from Fluentd
      def setfifo(conf)
        @fifo=true
        if !conf.elements(name: directionLabel).empty?
          directionset = conf[directionLabel].upercase

          # if the direction is set to LIFO switch the flag
          if directionset.eql? LIFOdirection
            @fifo=false
          elsif !(directionset.eql? FIFOdirection)
            @fifo=false
            log.warn directionLabel, " value not recognized ", directionset, " defaulting to ", FIFOdirection
          end
        end 
        return @fifo  
      end

      # this takes the log event and incorporates the original value (tag or time) into the log event
      # using the provided element name
      # @param data [String] structure holding the value to be inserted - this will be a base element using the structure used when storing the log event in Redis
      # @param data_record [String] log event record construct which needs the element adding to
      # @param key [String] the element in the Redis stored structure to be incorporated into the log event record i.e. time or tag
      # @param new_name [String] name string to use for the element going into the log event record structure
      # @return the data_record with the new attributed added
      def inject_original_value (data,data_record,key,new_name)
        log.debug "injecting original ", key

        if (data_record.length > 2)
          separator = SEPARATOR
        else
          separator = ''
        end
        # by inserting the details into the start of the string we only need to find the initial bracket
        # there is no need to parse the structure, worry about escaped characters etc
        data_record.insert(data_record.index('{')+1, '"'+new_name+'":'+data[key].to_s + separator)
        return data_record
      end

      # build a connection to Redis driven by the configuration values provided
      def connect_redis()
        log.trace "connect_redis called"
        if !@redis
          begin
            log.trace "initialize redis ", @hostaddr,":",@port
            @redis=Redis.new(host:@hostaddr,port:@port,connect_timeout:5,reconnect_attempts:2)
            log.trace "redis object initialized"
            log.debug "Connected to Redis "+@redis.connected?.to_s
          rescue Redis::BaseConnectionError, Redis::CannotConnectError => conn_err
            log.error "Connection error - ", conn_err.message, "\n connection timeout=", @connection_timeout, "\n connection attempts=", @reconnect_attempts
            @redis = nil
          rescue => err
            log.error "Error connecting to redis - ", err.message, "|",err.class.to_s
            @redis = nil
            return nil
          end
        end
      end

      # :section: Class Extensions
      # This overloads the Fluent::Input class methods for our requirements

      # tag the Redis entries and emit the log event so it is consumed by the next step in the Fluent chain of plugins
      # we keep popping from redis for as long as we can assuming we have a 
      # connection. Use our utilities to help with handling the events original time stamp
      def emit
        log.trace "emit triggered"
        if !@redis
          log.debug "reconnecting Redis ",@hostaddr,":",@port
          connect_redis()
        end

        # if we have a connection then we can try and pop entries
        # from the list
        if @redis
          keep_popping = true

          while keep_popping
            # pop from the list using the configured end
            if (@fifo)
              popped = @redis.rpop(@listname)
            else
              popped = @redis.lpop(@listname)
            end
    
            log.debug "Popped",@listname, ": ", popped
            # if we got a record from the list then let's process it
            if popped
              data = JSON.parse(popped)

              #decide what to do about the original time, if it's used
              # then set the log event time to the original value otherwise
              # time for the event is now
              if (@use_original_time)
                time = data[TimeAttributeLabel]
              else
                time = Fluent::EventTime.now
              end

              #decide what to do with the original tag
              if (@use_original_tag)
                tag = data[RedislistInput::TagAttributeLabel]
              else
                tag = @tag
              end

              # extract the original log event record
              data_record = data.fetch(RecordAttributeLabel).to_s
              log.debug "original data record=>",data_record

              if (@add_original_time && !(data_record.include? '"'+@add_original_time_name+'"'))
                data_record = inject_original_value(data,data_record,RedislistInput::TimeAttributeLabel,@add_original_time_name)
              end

              if @add_original_tag && !(data_record.include? '"'+@add_original_tag_name+'"')
                data_record = inject_original_value(data,data_record,RedislistInput::TagAttributeLabel,@add_original_tag_name)
              end

              log.debug "Emitting -->", tag," ", time, " ", data_record
              router.emit(tag, time, data_record)
            else
              # no more events so let the loop drop
              keep_popping = false
            end
          end
        else
          log.warn "No Redis - ", @redis
        end
      end

      # Setup the loop thread and if nothing to emit - go to sleep
      # implemented so we can control the thread sleep interval and invoke the
      # standard emit operation when its time.
      def run
        log.trace ("run triggered")
        while thread_current_running?
          current_time = Time.now.to_i

          emit() if thread_current_running?
          while thread_current_running? && Time.now.to_i <= current_time
            sleep @run_interval
          end
        end
      end

      # overload the configure(conf) to process the fifo/lifo configurartion option. But
      # invoke the parent as this will help with any other configuration options
      # @param conf [Object]  the Fluentd confguration object
      def configure(conf)
        super
        setfifo(conf)
      end

      # let's say hello to Redis and set out timed activity off.
      # Make use of the parent class to ensure that all ther associated 
      # basic operations such as tracking state
      def start
        super
        log.debug "starting redis plugin\n"
        connect_redis()

        thread_create(:RedislistInput, &method(:run))
      end

      #time to say goodbye to redis, invoke the parent class first to do the general 
      # shutdown tasks and then close the connection to Redis and relis the 
      # connection object
      def shutdown
        super
        log.trace "shutdown"

        if @redis 
          begin
            @redis.disconnect!
            log.debug "disconnecting from Redis\n"
            @redis = nil
          rescue
            log.error "Error closing Redis connection"
          end
        end
      end #shutdown

    end # class
  end
end
