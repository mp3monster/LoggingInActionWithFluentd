from ruby:2.6-slim-buster
LABEL maintainer "Phil Wilkins docker@mp3monster.org"
LABEL Description="simple setup to illustrate the behaviour of the daemonset - NOT fit for production use, good practise ignored in favour of ease of illustration around logging" Vendor="mp3monster" Version="1.0"
RUN apt-get update -y; \
  apt-get install -y; \
  apt-get install apt-utils -y; \
  apt-get install wget -y; \
  apt-get install -y --no-install-recommends \
            ca-certificates \
 && buildDeps=" \
      make gcc g++ libc-dev \
      wget bzip2 gnupg dirmngr \
    "; \
 apt-get install -y --no-install-recommends $buildDeps; \
 echo 'gem: --no-document' >> /etc/gemrc ; \
 gem install oj -v 3.10.18; \
 gem install json -v 2.4.1; \
 gem install async-http -v 0.54.0; \
 gem install ext_monitor -v 0.1.2; \
wget https://raw.githubusercontent.com/mp3monster/LoggingInActionWithFluentd/master/Chapter8/Docker/run.sh; \
chmod a+x run.sh
CMD ./run.sh