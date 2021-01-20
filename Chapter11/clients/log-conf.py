import logging
import logging.config
import yaml

with open('logging.yaml') as fd:
    conf = yaml.load(fd)

logging.config.dictConfig(conf['logging'])

log = logging.getLogger("test")
log.warning ('{"beep":"beep"}')