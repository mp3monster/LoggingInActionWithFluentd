# fluent-plugin-redisList

[Fluentd](https://fluentd.org/) output plugin that can send log events to a named [Redis](https://redis.io/) list ([redis.io]()). There is a partner plugin that can be used to retrieve log events from a Redis List. (https://github.com/mp3monster/UnifiedLoggingWithFluentd/tree/public/Chapter8/fluent-plugin-redislist).

The plugin can leverage the use of the in-memory buffer, but currently expects the chunks to be grouped by the log event tag and a number of log events rather than memory size. But a straight through synchronous behavior is applied if the <buffer> block is absent.

This plugin has been developed to facilitate  the illustration of plugin development as part of Chapter 8 of Unified Logging with Fluentd (https://www.manning.com/books/unified-logging-with-fluentd) - more information available [here](https://blog.mp3monster.org/publication-contributions/fluentd-unified-logging-with/). However the plugin is usable, but would benefit from some improvements to make it enterprise fit - the recommended improvements are described below.

### Value

The idea behind implementing both input and output plugins using a Redis list is to provide:

* an alternative mechanism to using the in-memory buffer framework for caching log events.
* Support work load shedding when underload through exploitation of the Redis time-to-live mechanisms
* another option for scaling by having different Fluentd nodes pushing and popping from the in memory storage.
* allow memory buffered data to be secured by exploiting the Redis DB persistence mechanisms.



### Recommended Feature Enhancements

The following are suggested features that could be considered for the input and output plugins:

* Extend to support the different authentication mechanisms Redis will support .
* Extend to use SSL/TLS connectivity - essential when using authenticated access.
* Support Asynchronous Memory Buffer use.
* Connect to other Redis structures to read and write, using a separate structure for tracking progress (i.e. cursor position recording rather than popping content).
* Allow additional configurations of the memory buffering e.g. use of memory size controls.
* Collect execution metrics.
* Enhance configuration metrics to validate provided values.
* Make the use of the list LIFO or FIFO based on configuration.



##### Quality Improvement

* Extend coverage of unit testing

* Develop Rake file and support the use of Lint

* Test functionality with multiple workers to ensure thread safe

  

## Installation

### RubyGems

```
$ gem install fluent-plugin-redisList
```



## Configuration

## Fluent::Plugin::RedislistOutput

### port (integer) (optional)

specifies the port to connect to Redis with, will default to 6379 if not specified

Default value: `6379`.

Alias: port

### hostaddr (string) (optional)

Defines the host address for Redis, if not defined 127.0.0.1

Default value: `127.0.0.1`.

### listname (string) (optional)

Defines the name of the list to be used in Redis, by default this is Fluentd

Default value: `fluentd`.

### reconnect_attempts (integer) (optional)

Defines the number of reconnection attempts before giving up on connecting to the Redis server

Default value: `2`.

### connection_timeout (integer) (optional)

Defines the number of seconds before timing out a connection to the Redis server

Default value: `5`.


### \<buffer\> section (optional) (multiple)

#### @type () (optional)



Default value: `memory`.

#### chunk_keys () (optional)



Default value: `["tag"]`.

#### chunk_limit_records () (optional)



## Copyright

* Copyright(c) 2020- Phil Wilkins
* License
  * [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
