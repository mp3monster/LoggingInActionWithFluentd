#This implementation makes use of the Fluentd implementation directly without the use of
# the Python logging framework
import datetime, time
from fluent import handler, sender

fluentSender = sender.FluentSender('test', host='localhost', port=18090)
# using the Fluentd Handler means that msgpack will be used and therefore the source plugin in Fluentd is a forward plugin.
now = datetime.datetime.now().strftime("%d-%m-%Y %H-%M-%S")
fluentSender.emit_with_time('', int(time.time()), {'from': 'log-fluent', 'at': now})
