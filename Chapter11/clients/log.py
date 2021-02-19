#This implementation makes no use of the Python logging framework or the Fluentd 
# logging library. It uses pure HTTP based traffic.
import httplib, urllib
import datetime

message = '{"from":"log.py", "at":"'+datetime.datetime.now().strftime("%d-%m-%Y %H-%M-%S")+'"}'
headers = {"Content-Type": "application/JSON", "Accept": "text/plain", "Content-Length":len(message)}
conn = httplib.HTTPConnection("localhost:18085")
conn.request("POST", "/test", message, headers)

response = conn.getresponse()
print response.status, response.reason
conn.close()
