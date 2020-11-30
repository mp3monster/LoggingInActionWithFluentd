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

#module Fluent
#  module Plugin
    class RedislistOutput < Fluent::Plugin::Output
      Fluent::Plugin.register_output("redislist", self)

      config_param :portNo, :integer, default: 6379, :secret false
      config_param :hostAddr, :string, default: "localhost", secret: false; alias: host_address
      config_param :listName, :string, default: "fluentd"

      # use the Redis connection as a member variable so we don't need to keep constructing connections
      # each time we need to perform an operation
      @redisConnection :Redis
      # We could enhance connection handling with:
      # - provide the option to include username and password
      # - HTTPS connectivity
      # - connection pooling
      # - specify connection timeouts and reconnection behavior

      def process(tag, es)
        buildConnection
        @redisConnection.multi do
          es.each do |time, record|
            $stdout.write redisConnection.lpush (listName, buildListEntry(tag, time, record))
          end
        end
      end

      # create the Redis connection only if the connection is nil
      def buildConnection()
        if @redisConnection.nil 
          @redisConnection = Redis.new (host:hostAddr, port:portno)
        end
      end

      # combine the Fluentd tag, timestamp and record into a JSON payload
      # as we don't knowe for sure whether the record will be JSON in nature - easiest if we process
      # everything as a string.
      def buildListEntry (tag, time, record)
        return '{"tag" : '+ tag + ",time" : ' + time + ', "record" :'+record+'"}'
      end

    end
#  end
# end
