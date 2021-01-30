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

require "fluent/plugin/output"
require "redis"
# we need the Redis gem to help

module Fluent
  module Plugin
    # Output plugin for Fluentd using Redis Lists
    # all of our methods include the use of Trace - whilst typically this would be overkill, it does
    # help with observing how the plugin is working
    # @see https://blog.mp3monster.org/publication-contributions/fluentd-unified-logging-with/
    #todo: For candidate functional improvements see the readme-final.md file
    class RedislistOutput < Fluent::Plugin::Output
      Fluent::Plugin.register_output("redislist", self)
      helpers :event_emitter


      # the label used to identify the tag part of a log event when added to Redis
      TagAttributeLabel = "tag"
      # the label used to identify the time part of a log event when added to Redis
      TimeAttributeLabel = "time"
      # the label used to identify the actual log event record part of a log event when added to Redis
      RecordAttributeLabel = "record"

      # As we reference the port element of the configuration in several places, defined as a constant
      PortConfigLabel = 'port'

      #define the default Redis port is no configuration is supplied, and warn if the default is not being used
      DefaultPort = 6379

      # :section: configuration parameters
      # define the configuration parameters that will tell us where to connect to the Fluentd instance
      desc "specifies the port to connect to Redis with, will default to 6379 if not specified"
      config_param :port, :integer, default: 6379, secret: false, alias: :portNo

      desc "Defines the host address for Redis, if not defined 127.0.0.1"
      config_param :hostaddr, :string, default: "127.0.0.1", secret: false

      desc "Defines the name of the list to be used in Redis, by default this is Fluentd"
      config_param :listname, :string, default: "fluentd"

      desc "Defines the number of reconnection attempts before giving up on connecting to the Redis server"
      config_param :reconnect_attempts, :integer, default: 2

      desc "Defines the number of seconds before timing out a connection to the Redis server"
      config_param :connection_timeout, :integer, default: 5
      
      desc "Defines the number of log events in a chunk"
      config_param :chunksize, :integer, default: 20

      #setup the buffer configuration
      config_section :buffer do
        config_set_default :@type, 'memory'
        config_set_default :chunk_keys, ["tag"]
        config_set_default :chunk_limit_records, @chunksize
      end


      # use the Redis connection as a member variable so we don't need to keep constructing connections
      # each time we need to perform an operation
      @redis

      # :section: Utilities

      # build the representation of the log event to be used within Redis.
      # We've not overloaded the format operation as that disrupts default behaviors
      
      # Takes the log event and builds a representation of it ready for storing into Redis
      #
      # @param [String] tag the tag being used for this log event
      # @param [Integer] time expressed as seconds from epoch
      # @param [String] record representing the log event itself
      # @return [String] a JSON formatted string ready for storing into Redis
      def redisFormat(tag,time,record)
        redis_entry = Hash.new
        redis_entry.store(RedislistOutput::TagAttributeLabel,tag.to_s)
        redis_entry.store(RedislistOutput::TimeAttributeLabel,time.to_i)
        redis_entry.store(RedislistOutput::RecordAttributeLabel,record.to_s)
        redis_out = JSON.generate(redis_entry)
        return redis_out
      end

      # locates the port configuration if it is set and then will generate a warning reminder to ensure ports
      # should be checked to ensure they don't clash if the standard port is not being used.
      # @param [conf] configuration data recieved from the Fluentd framework
      def check_port(conf)
        log.trace "checkport invoked"
        port = conf[PortConfigLabel]
        if (port != RedislistOutput::DefaultPort)
          log.info ("Default Redis port in use")
        else
          log.warn ("Non standard Redis port in use - ensure ports are deconflicted")
        end
      end

      # locates the buffer  configuration if set then log the chunk size setting information
      # @param [conf] configuration data recieved from the Fluentd framework
      def check_buffer(conf)
        log.trace "checkport invoked"
        if !conf.elements(name: 'buffer').empty?
          log.info "buffer set; size=", conf.elements(name: 'chunk_limit_records')
        end   
      end

      # Builds a connection to Redis using the relevant parameters provided including details such as retries and timeouts
      # log whether we have connected or not.  If there is a redis connection failure ensure that the connection object is
      # not set and log the cause of the connection issue
      # @return [Redis connection] connection object or nil if there is an error
      def connect_redis()
        log.trace "connect_redis - Create connection if non existant"
        if !@redis
          begin
            @redis=Redis.new(host:@hostaddr,port:@port,connect_timeout:@connection_timeout,reconnect_attempts:@reconnect_attempts)
            log.debug "Connected to Redis "+@redis.connected?.to_s
          rescue Redis::BaseConnectionError, Redis::CannotConnectError => conn_err
            log.error "Connection error - ", conn_err.message, "\n connection timeout=", @connection_timeout, "\n connection attempts=", @reconnect_attempts
            @redis = nil
            return nil
          rescue => err
            log.error "Error connecting to redis - ", err.message, "|",err.class.to_s
            @redis = nil
            return nil
          end
        end
      end

      # :section: Class Extensions
      # This overloads the Fluent::Output class methods for our requirements

      # process the received events - pushing them onto the list. Tell Redis to handle multiple operations
      # on the presumption that es may contain multiple log events
      # @param [tag] the tag associated to these log event(s)
      # @param [es] one or more log events to process with the timestamp and record
      def process(tag,es)
        log.trace "process request received ", tag

        if !@redis
          connect_redis()
        end

        if (@redis.connected?)
          @redis.multi
            es.each do |time, record|
              log.debug "process redis push:", tag, time, record, @listname
              @redis.lpush(@listname,redisFormat(tag,time,record))
            end
          
          @redis.exec
        else
          log.warn "no connection to Redis"
          router.emit_error_event(tag, time, record, "No Redis")
        end
      end

      # implement our own version of write as we support the use of ther buffer, with a synchronous write
      # @param [chunk] the buffer chunk
      def write(chunk)
        log.trace "write:", chunk

        @redis.multi 
          chunk.each do |time, record|
            log.debug "write sync redis push ", chunk.metadata.tag, time, record, @listname
            @redis.lpush(@listname,redisFormat(chunk.metadata.tag,time,record))
          end
        @redis.exec
      end

      # configure extended to perform some checks and validation on the buffer and port settings
      # we've delegated each check to its own method
      # @param [conf] configuration data from the Fluentd framework
      def configure(conf)
        super
        log.trace "configure(conf)"
        check_port(conf)
        check_buffer(conf)
      end

      # we need to use super as it will cover the handling of secondary behavior and any tasks 
      # relating to the buffer. The base class handles tracking of state - super will ensure that is done as well
      # once the parent has completed its action's we'll get a Redis connection created. Better to create the 
      # connection now as these things are relatively slow to be established.
      def start
        super
        log.trace "starting redis plugin\n"
        connect_redis()
      end

      # we need to use super as it will cover the handling of secondary behavior and any tasks 
      # relating to the buffer.The base class handles tracking of state - super will ensure that is done as well
      # Once the parent class has finished we'll get the Redis connection to be close and then drop the connection
      # object.
      def shutdown
        super
        log.trace "shutdown"
        if @redis 
          begin
            @redis.disconnect!
            log.debug "disconnecting from redis\n"
            @redis = nil
          rescue
            log.error "Error closing Redis connection"
          end
        end
      end      

    end
  end
 end
