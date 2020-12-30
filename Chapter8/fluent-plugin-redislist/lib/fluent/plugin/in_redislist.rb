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
    class RedislistInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("redislist", self)

      helpers :thread

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

      directionLabel = "direction"
      FIFOdirection = "FIFO"
      LIFOdirection = "LIFO"

      desc "Process as FIFO or as LIFO"
      config_param :direction, :string, default: "FIFO"    
    
      # the labels to identify the three core constructs of a log event when added to Redis
      TagAttributeLabel = "tag"
      TimeAttributeLabel = "time"
      RecordAttributeLabel = "record"      

      keep_running = true
      SEPARATOR = ','

      # use the Redis connection as a member variable so we don't need to keep constructing connections
      # each time we need to perform an operation
      @redis

      @fifo = true

      def injectOriginalValue (data, data_record, key, new_name)
        log.debug "injecting original ", key

        if (data_record.length > 2)
          separator = SEPARATOR
        else
          separator = ''
        end
        data_record.insert(data_record.index('{')+1, '"'+new_name+'":'+data[key].to_s + separator)
        return data_record
      end

      # tag the Redis entries and emit the log event so it is consumed by the next step in the Fluent chain of plugins
      def emit
          log.trace "emit triggered"
          if !@redis
            log.debug "reconnecting Redis ",@hostaddr,":",@port
            connect_redis()
          end

          if @redis
            keep_popping = true

            while keep_popping
              if (@fifo)
                popped = @redis.rpop(@listname)
              else
                popped = @redis.lpop(@listname)
              end
    
              log.debug "Popped",@listname, ": ", popped
              if popped
                data = JSON.parse(popped)
                if (@use_original_time)
                  time = data[TimeAttributeLabel]
                else
                  time = Fluent::EventTime.now
                end

                if (@use_original_tag)
                  tag = data[RedislistInput::TagAttributeLabel]
                else
                  tag = @tag
                end

                data_record = data.fetch(RecordAttributeLabel).to_s
                log.debug "original data record=>",data_record

                if (@add_original_time && !(data_record.include? '"'+@add_original_time_name+'"'))
                  data_record = injectOriginalValue(data,data_record,RedislistInput::TimeAttributeLabel,@add_original_time_name)
                end

                if @add_original_tag && !(data_record.include? '"'+@add_original_tag_name+'"')
                  data_record = injectOriginalValue(data,data_record,RedislistInput::TagAttributeLabel,@add_original_tag_name)
                end

                log.debug "Emitting -->", tag," ", time, " ", data_record
                router.emit(tag, time, data_record)
              else
                keep_popping = false
              end
            end
          else
            log.warn "No Redis - ", @redis
          end
        end

      #time to do something?
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

      def setfifo(conf)
        @fifo=true
        if !conf.elements(name: 'directionLabel').empty?
          directionset = conf[directionLabel].upercase

          if directionset.eql? LIFOdirection
            @fifo=false
          elsif !(directionset.eql? FIFOdirection)
            @fifo=false
            log.warn directionLabel, " value not recognized ", directionset, " defaulting to ", FIFOdirection
          end
        end   
      end


      def configure(conf)
        super
        setfifo(conf)
      end

      # let's say hello to Redis and set out timed activity off
      def start
        super
        log.debug "starting redis plugin\n"
        connect_redis()

        thread_create(:RedislistInput, &method(:run))
      end

      #time to say goodbye to redis
      def shutdown
        super

        if @redis 
          begin
            @redis.disconnect!
            log.debug "disconnecting from Redis\n"
            @redis = nil
          rescue
            log.error "Error closing Redis connection"
          end
        end
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

    end
  end
end
