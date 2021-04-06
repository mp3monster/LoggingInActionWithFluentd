apt-get install wget -y; \
apt-get install ruby -y; \
gem install fluentd; \
wget https://raw.githubusercontent.com/mp3monster/LoggingInActionWithFluentd/master/Chapter8/Fluentd/file-forward.conf; \
echo file is $FLUENT_SOURCE_PATH; \
echo host is $FLUENT_FOWARD_HOST; \
echo port is $FLUENT_FOWARD_PORT; \
fluentd -c ./file-forward.conf 