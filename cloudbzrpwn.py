import time
import socket
import urllib
import urllib2
import re
from urllib2 import URLError
import cloud
import os
import redis

# This (horribly written) script will read in a line of domains in format of example.com, one per line and create a job out of those domains and send it to picloud for processing. You must signup for picloud and put in your API key below. 

# Current issues:
#  Does not support HTTPS (manually change it

cloud.setkey("#####", "####################")
set = "dvcspwns"
redis_host = "example.com"
host_list = "dvcshostlist"
#cloud.start_simulator()

# Size of job to run
chunksize = 1000
start = 0
timeout = 10

def chunks(start, size):
    f = open(host_list)
    patterns = []
    count = 0
    lines = []
    for line in f:
        if count < start:
            count = count + 1
        elif count < start + chunksize:
            lines.append("http://%s/.bzr/README" % line.split(",")[0].rstrip())
            patterns.append('^This\sis\sa\sBazaar')
            count = count + 1
        else:
            break
    f.close()
    return lines,patterns


def check_git(url,pattern):
        request = urllib2.Request("%s" % (url))
        try:
                response = urllib2.urlopen(request)
        except Exception, e:
                return False, ""
        else:
                result =  response.read()
                match = re.search(pattern,result)
                if match is None:
                        return False, ""
                else:
                        r = redis.Redis(redis_host)
                        r.sadd(set,url)
                        return True, result

try:
    lines,patterns = chunks(start,chunksize)
    print cloud.map(check_git,lines, patterns)
except Exception, e:
    print e
