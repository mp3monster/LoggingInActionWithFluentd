cd .\Chapter4
rm fluentd-file-output.*.log
rm structured-rolling-log.*.log
rmel rotating-file-read.pos_file
rm fluentd-file-output.*.gz
rm -rf fluentd-file-output 
mongo < ..\cleanup4.js
cd ..