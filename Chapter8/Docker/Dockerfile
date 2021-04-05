from debian
LABEL maintainer "Phil Wilkins docker@mp3monster.org"
LABEL Description="simple setup to illustrate the behaviour of the daemonset" Vendor="mp3monster" Version="1.0"
RUN wget https://raw.githubusercontent.com/mp3monster/LoggingInActionWithFluentd/master/Chapter8/Docker/run.sh; \
  wget https://raw.githubusercontent.com/mp3monster/LoggingInActionWithFluentd/master/Chapter8/Fluentd/file-forward.conf; \
  chmod a+x run.sh
CMD ./run.sh