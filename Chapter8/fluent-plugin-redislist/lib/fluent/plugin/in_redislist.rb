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

module Fluent
  module Plugin
    class RedislistInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("redislist", self)

      helpers :thread

      config_param :port, :integer, default: 6379, secret: false, alias: :port
      config_param :hostaddr, :string, default: "127.0.0.1", secret: false
      config_param :listname, :string, default: "fluentd"
      config_param :run_interval, :integer, default: 1
      config_param :use_original_time, :bool, default:false
      config_param :use_original_tag, :bool, default:false
      config_param :add_original_time, :bool, default:true
      config_param :add_original_tag, :bool, default:true
      config_param :add_original_tag_name, :string, default: "originalTag"
      config_param :add_original_time_name, :string, default: "originalTime"
      config_param :tag, :string, default: @type
    
      # the labels to identify the three core constructs of a log event when added to Redis
      TagAttributeLabel = "tag"
      TimeAttributeLabel = "time"
      RecordAttributeLabel = "record"      

      keep_running = true
      SEPARATOR = ','

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
          if @redis
            keep_popping = true

            while keep_popping
              popped = @redis.lpop(@listname)
    
              if popped
                log.debug "Popped:", popped
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

      # let's say hello to Redis and set out timed activity off
      def start
        super
        log.debug "starting redis plugin\n"
        connect_redis()

        thread_create(:RedislistInput, &method(:run))
      end

      #timer to say goodbye to redis
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

      # build a connection to Redis driven by the configuration values provided
      def connect_redis()
        if !@redis
          begin
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
