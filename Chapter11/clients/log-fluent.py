import logging
from fluent import handler

testHandler = handler.FluentHandler('', host='localhost', port=18095)

custom_format = {
  'host': '%(hostname)s',
  'where': '%(module)s.%(funcName)s',
  'type': '%(levelname)s',
  'stack_trace': '%(exc_text)s'
}
formatter = handler.FluentRecordFormatter(custom_format)
testHandler.setFormatter(formatter)

log = logging.getLogger("test")
log.addHandler(testHandler)
log.warning ('{"beep":"beep"}')