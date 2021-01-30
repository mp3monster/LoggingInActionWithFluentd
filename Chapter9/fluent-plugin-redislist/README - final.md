# fluent-plugin-redislist

[Fluentd](https://fluentd.org/) input plugin to retrieve entries from a Redis List.  For more information checkout the partner plugin detailed at -  https://github.com/mp3monster/UnifiedLoggingWithFluentd/blob/public/Chapter8/fluent-plugin-out-redislist/README%20-%20final.md



## Installation

### RubyGems

```
$ gem install fluent-plugin-redislist
```



## Configuration

## Fluent::Plugin::RedislistInput

### port (integer) (optional)

specifies the port to connect to Redis with, will default to 6379 if not specified

Default value: `6379`.

Alias: portNo

### hostaddr (string) (optional)

Defines the host address for Redis, if not defined 127.0.0.1

Default value: `127.0.0.1`.

### reconnect_attempts (integer) (optional)

Defines the number of reconnection attempts before giving up on connecting to the Redis server

Default value: `2`.

### connection_timeout (integer) (optional)

Defines the number of seconds before timing out a connection to the Redis server

Default value: `5`.

### listname (string) (optional)

Defines the name of the list to be used in Redis, by default this is Fluentd

Default value: `fluentd`.

### run_interval (integer) (optional)

The frequency in seconds between checking in with Redis for log events

Default value: `1`.

### use_original_time (bool) (optional)

determine whether or not to set the log event time to the original time it occured, rather than the time when the event was retrieved from Redis

### use_original_tag (bool) (optional)

determine whether or not to set the log event tag to the original tag used when the event was stored in Redis, rather than the tag when the event was retrieved from Redis

### add_original_time (bool) (optional)

Indicates whether the original event timestamp should be included into the log event record

Default value: `true`.

### add_original_tag (bool) (optional)

Indicates whether the original event tag should be included into the log event record

Default value: `true`.

### add_original_tag_name (string) (optional)

Defines the attribute name to be used in the log event record if original event tag should be included

Default value: `originalTag`.

### add_original_time_name (string) (optional)

Defines the attribute name to be used in the log event record if original event timestamp should be included

Default value: `originalTime`.

### tag (string) (optional)

Sets the tag if not defined to match the plugin type



## Copyright

* Copyright(c) 2020- Phil Wilkins
* License
  * Apache License, Version 2.0
