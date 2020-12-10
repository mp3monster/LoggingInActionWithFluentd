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
    
      
      keep_running = true
      SEPARATOR = ','

      def emit
          log.trace ("emit triggered")
          if @redis
            keep_popping = true

            while keep_popping
              popped = @redis.lpop(@listname)
    
              if popped
                log.debug ("Popped:"+popped)
                data = JSON.parse(popped)
                if (@use_original_time)
                  time = data["time"]
                else
                  time = Fluent::EventTime.now
                end

                if (@use_original_tag)
                  tag = data["tag"]
                else
                  tag = @tag
                end

                data_record = data.fetch("record").to_s
                log.debug "original data record=>",data_record

                if @add_original_time && !(data_record.include? '"'+@add_original_time_name+'"')
                  log.debug ("injecting original time")

                  if (data_record.length > 2)
                    separator = SEPARATOR
                  else
                    separator = ''
                  end

                  data_record.insert(data_record.index('{')+1, '"'+@add_original_time_name+'":'+data["time"].to_s + separator)
                end

                if @add_original_tag && !(data_record.include? '"'+@add_original_tag_name+'"')
                  log.debug ("injecting original name")

                  if (data_record.length > 2)
                    separator = SEPARATOR
                  else
                    separator = ''
                  end

                  data_record.insert(data_record.index('{')+1, '"'+@add_original_tag_name+'":"'+data["tag"]+'"' + separator)
                end

                log.debug "Emitting -->", tag," ", time, " ", data_record
                router.emit(tag, time, data_record)
              else
                keep_popping = false
              end
            end
          end
        end

      def run
        log.trace ("callback triggered")
        while thread_current_running?
          current_time = Time.now.to_i

          emit() if thread_current_running?
          while thread_current_running? && Time.now.to_i <= current_time
            sleep @run_interval
          end
        end
  

      end

      def start
        super
        log.debug "starting redis plugin\n"
        connect_redis()

        thread_create(:RedislistInput, &method(:run))
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
