cd ./Chapter4
del fluentd-file-output.*.log
del structured-rolling-log.*.log
del rotating-file-read.pos_file
del fluentd-file-output.*.gz
rmdir fluentd-file-output 
mongo < ../cleanup4.js
cd ..