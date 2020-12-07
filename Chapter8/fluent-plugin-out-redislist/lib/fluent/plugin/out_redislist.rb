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

      DefaultPort = 6379

      config_param :port, :integer, default: 6379, secret: false, alias: :port
      config_param :hostaddr, :string, default: "127.0.0.1", secret: false
      config_param :listname, :string, default: "fluentd"

      # use the Redis connection as a member variable so we don't need to keep constructing connections
      # each time we need to perform an operation
      @redis
      # We could enhance connection handling with:
      # - provide the option to include username and password
      # - HTTPS connectivity
      # - connection pooling
      # - specify connection timeouts and reconnection behavior

      def process(tag,es)
        if !@redis
          connect_redis()
        end

        log.debug "Request received"

        @redis.multi do
          es.each do |time, record|
            log.debug time
            log.debug record
            if (@redis.connected?)
              redis_out = '{"tag" : "'+tag.to_s+'",time" : '+ time.to_s+', "record" :"'+record.to_s+'"}'
              @redis.lpush(@listname,redis_out)
              log.info "lpushed to "+@listname+"payload="+redis_out
            else
              log.warn "no connection to Redis"
              router.emit_error_event(tag, time, record, "No Redis")
            end
          end
        end
      end

      def configure(conf)
        super
        port = conf['port']
        if (port != RedislistOutput::DefaultPort)
          log.info ("Default Redis port in use")
        else
          log.warn ("Non standard Redis port in use - ensure ports are deconflicted")
        end
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
          #@redis=Redis.new(host:@hostaddr,port:@port)
          #@redis=Redis.new(host:"127.0.0.1",port:@port,connect_timeout:5,reconnect_attempts:2)
          @redis=Redis.new(host:@hostaddr,port:@port,connect_timeout:5,reconnect_attempts:2)
          @redis.connect!
          log.debug "Connected to Redis "+@redis.connected?.to_s
          rescue
            log.error "Error connecting to redis"
            return nil
          end
        end
      end

    end
  end
 end
