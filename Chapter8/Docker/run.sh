apt-get install wget -y \
&& apt-get install ruby -y \
&& apt-get install -y --no-install-recommends \
            ca-certificates \
 && buildDeps=" \
      make gcc g++ libc-dev \
      wget bzip2 gnupg dirmngr \
    " \
 && apt-get install -y --no-install-recommends $buildDeps \
 && echo 'gem: --no-document' >> /etc/gemrc \
 && gem install oj -v 3.10.18 \
 && gem install json -v 2.4.1 \
 && gem install async-http -v 0.54.0 \
 && gem install ext_monitor -v 0.1.2 \
&& wget https://raw.githubusercontent.com/mp3monster/LoggingInActionWithFluentd/master/Chapter8/Fluentd/file-forward.conf  \
&& gem install fluentd \
&& cat file-forward.conf \
&& echo file is $FLUENT_SOURCE_PATH \
&& echo host is $FLUENT_FOWARD_HOST \
&& echo port is $FLUENT_FOWARD_PORT \
fluentd -c ./file-forward.conf 