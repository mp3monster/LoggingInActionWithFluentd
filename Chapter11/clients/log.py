import logging, logging.handlers
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

log.warning ('{"beep":"beep"}')