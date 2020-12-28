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
    class RedislistOutput < Fluent::Plugin::Output
      Fluent::Plugin.register_output("redislist", self)
      helpers :event_emitter

      # the labels to identify the three core constructs of a log event when added to Redis
      TagAttributeLabel = "tag"
      TimeAttributeLabel = "time"
      RecordAttributeLabel = "record"

      PortConfigLabel = 'port'

      DefaultPort = 6379

      desc "specifies the port to connect to Redis with, will default to 6379 if not specified"
      config_param :port, :integer, default: 6379, secret: false, alias: :port
      desc "Defines the host address for Redis, if not defined 127.0.0.1"
      config_param :hostaddr, :string, default: "127.0.0.1", secret: false
      desc "Defines the name of the list to be used in Redis, by default this is Fluentd"
      config_param :listname, :string, default: "fluentd"
      desc "Defines the number of reconnection attempts before giving up on connecting to the Redis server"
      config_param :reconnect_attempts, :integer, default: 2
      desc "Defines the number of seconds before timing out a connection to the Redis server"
      config_param :connection_timeout, :integer, default: 5
      

      #setup the buffer configuration
      config_section :buffer do
        config_set_default :@type, 'memory'
        config_set_default :chunk_keys, ["tag"]
        config_set_default :chunk_limit_records, 20
      end


      # use the Redis connection as a member variable so we don't need to keep constructing connections
      # each time we need to perform an operation
      @redis
      # We could enhance connection handling with:
      # - provide the option to include username and password
      # - HTTPS connectivity
      # - connection pooling
      # - specify connection timeouts and reconnection behavior

      def redisFormat(tag,time,record)
        redis_entry = Hash.new
        redis_entry.store(RedislistOutput::TagAttributeLabel,tag.to_s)
        redis_entry.store(RedislistOutput::TimeAttributeLabel,time.to_i)
        redis_entry.store(RedislistOutput::RecordAttributeLabel,record.to_s)
        redis_out = JSON.generate(redis_entry)
        return redis_out
      end

      def process(tag,es)
        if !@redis
          connect_redis()
        end

        log.trace "process request received"
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

      def write(chunk)
        log.debug chunk

        @redis.multi 
          chunk.each do |time, record|
            log.debug "write sync redis push ", chunk.metadata.tag, time, record, @listname
            @redis.lpush(@listname,redisFormat(chunk.metadata.tag,time,record))
          end
        @redis.exec
      end

      def checkPort(conf)
        port = conf[PortConfigLabel]
        if (port != RedislistOutput::DefaultPort)
          log.info ("Default Redis port in use")
        else
          log.warn ("Non standard Redis port in use - ensure ports are deconflicted")
        end
      end

      def checkBuffer(conf)
        if !conf.elements(name: 'buffer').empty?
          log.info "buffer set; size=", conf.elements(name: 'chunk_limit_records')
        end   
      end


      def configure(conf)
        super
        checkPort (conf)
        checkBuffer(conf)
      end

      def start
        super
        log.debug "starting redis plugin\n"
        connect_redis()
      end

      def shutdown
        super
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

      def connect_redis()
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

    end
  end
 end
