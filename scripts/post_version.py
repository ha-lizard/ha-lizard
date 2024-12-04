#!/usr/bin/python
########################################
#Script is called one time at installation
#Version number is passed to help
#in gathering usage statistics
########################################
import sys
null = open('/dev/null', 'w')
sys.stderr = null
import urllib2
version = str(sys.argv[1])
urllib2.urlopen("http://halizard.pulse-lists.com/count.php?VERSION="+version)
