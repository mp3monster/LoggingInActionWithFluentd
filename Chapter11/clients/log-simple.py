#This approach makes use of the Python logging without any Fluentd provided logging 
# functionality. As a result we have fallen back to sending HTTP and using a custom
# formatter to populate the values we would see through the configuration
import logging, logging.handlers
import datetime
testHandler = logging.handlers.HTTPHandler('localhost:18080', '/test', method='POST')
custom_format = {
  'host': '%(hostname)s',
  'where': '%(module)s.%(funcName)s',
  'type': '%(levelname)s',
  'stack_trace': '%(exc_text)s'
}
formatter = logging.Formatter(custom_format)
testHandler.setFormatter(formatter)

log = logging.getLogger("test")
log.addHandler(testHandler)
now = datetime.datetime.now().strftime("%d-%m-%Y %H-%M-%S")
log.warning ('{"from":"log-fluent-simple", "at" :'+now+'"}')