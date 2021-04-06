from ruby:2.6-slim-buster
LABEL maintainer "Phil Wilkins docker@mp3monster.org"
LABEL Description="simple setup to illustrate the behaviour of the daemonset - NOT fit for production use, good practise ignored in favour of ease of illustration around logging" Vendor="mp3monster" Version="1.0"
RUN apt-get update -y; \
  apt-get install -y; \
  apt-get install apt-utils -y; \
  apt-get install wget -y; 
CMD wget https://raw.githubusercontent.com/mp3monster/LoggingInActionWithFluentd/master/Chapter8/Docker/run.sh; \
  && chmod a+x run.sh \
  && ./run.sh