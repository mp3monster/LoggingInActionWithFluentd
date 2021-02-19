# This implementation makes full use of the Python logging framework and the 
# fluentd python implementation is used by the fact it is referenced in the 
# configuration and is compliant to the interfaces needed by Python

import logging
import logging.config
import yaml
import datetime

with open('logging.yaml') as fd:
    conf = yaml.load(fd, Loader=yaml.FullLoader)

logging.config.dictConfig(conf['logging'])

log = logging.getLogger()
now = datetime.datetime.now().strftime("%d-%m-%Y %H-%M-%S")
log.warning ('from log-conf.py at ' + now)
log.info ('{"from": "log-conf.py", "now": '+now+'"}')