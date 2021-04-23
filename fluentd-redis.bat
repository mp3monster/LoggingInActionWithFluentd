start "Redis" redis-server 
sleep 10
title Fluentd
Fluentd -c .\Chapter8\Fluentd\dummy-plugin2.conf -p E:\dev\GitHub\UnifiedLoggingWithFluentd\Chapter8\fluent-plugin-out-redislist\lib\fluent\plugin  -p E:\dev\GitHub\UnifiedLoggingWithFluentd\Chapter8\fluent-plugin-redislist\lib\fluent\plugin
