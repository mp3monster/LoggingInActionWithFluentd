from groovy
LABEL maintainer "Phil Wilkins docker@mp3monster.org"
LABEL Description="LogSimulator docker image" Vendor="mp3monster" Version="1.0"
RUN sudo apt-get install wget; wget https://raw.githubusercontent.com/mp3monster/LogGenerator/master/docker/run.sh; \
  wget https://raw.githubusercontent.com/mp3monster/LogGenerator/master/LogSimulator.groovy; \
  chmod a+x run.sh
CMD ./run.sh