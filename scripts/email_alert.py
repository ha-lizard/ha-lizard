#!/usr/bin/env python

import sys, socket, smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText

##########################
# Suppress stderr in case
# network/DNS  is down
##########################
#null = open('/dev/null', 'w')
#sys.stderr = null

###########################
# if network or DNS is down
# dont wait - exit 1
###########################
socket.setdefaulttimeout(2)

if len(sys.argv) != 11:
	print ("HA-Lizard email alert sender. Version 1.0 www.halizard.com")
	print ("Pass in all command line arguments as follows")
	print ("<command> from_email to_email subject timestamp process_name message_body smtp_server smtp_port smtp_user smtp_pass")
	sys.exit(1)

#############################
#Declare System Hostname
#############################
hostname = socket.gethostname()

#############################
# Declare passed in args
#############################
from_email = str(sys.argv[1])
to_email = str(sys.argv[2])
subject = str(sys.argv[3])
timestamp = str(sys.argv[4])
process_name = str(sys.argv[5])
message_body = str(sys.argv[6])
smtp_server = str(sys.argv[7])
smtp_port =  str(sys.argv[8])
smtp_user =  str(sys.argv[9])
smtp_pass =  str(sys.argv[10])

#############################
# Echo to stdout - halizard
# redirects to log
#############################
print "Sending email from: "+from_email
print "Sending email to: "+to_email
print "Email Alert Subject: "+subject
print "Email Alert Timestamp: "+timestamp
print "Email Alert Process: "+process_name
print "Email Alert Message Content: "+message_body
print "Email Alert Message Hostname: "+hostname

###############################
# Create the message headers
###############################
msg = MIMEMultipart('alternative')
msg['Subject'] = subject
msg['From'] = from_email
msg['To'] = to_email

# Create the body of the message (a plain-text and an HTML version).
###############################
# Message body - Text
###############################
text = message_body

###############################
# Message body - HTML
###############################
message_body_html="<br />".join(message_body.split("\n"))
html = """\
<table height="100" cellspacing="1" cellpadding="1" border="1" width="600" style="">
    <tbody>
        <tr>
            <td width="160"><img height="111" width="150" src="http://www.halizard.com/images/ha_lizard_alert_logo.png" alt="" /></td>
            <td width="440"><span style="color: rgb(0, 102, 0);"><strong><span style="font-size: larger;"><span style="font-family: Arial;">HA-Lizard Alert Notification<br />
            <br />
            Process: %s <br />
            Host: %s <br />
            Time: %s </span></span></strong></span></td>
        </tr>
        <tr>
            <td width="600" colspan="2">
            <p><br />
            <span style="font-family: Arial;"><span style="font-size: smaller;"> %s <br />
            <br />
            </span></span></p>
            </td>
        </tr>
        <tr>
            <td bgcolor="#cccccc" width="600" colspan="2">
            <p style="text-align: left;"><strong><span style="font-size: smaller;"><span style="font-family: Arial;">website</span></span></strong><span style="font-size: smaller;"><span style="font-family: Arial;">: www.halizard.com&nbsp;&nbsp;&nbsp;&nbsp; <strong>forum</strong>: http://www.halizard.com/forum</span></span>&nbsp;&nbsp;&nbsp; <strong><span style="font-size: smaller;"><span style="font-family: Arial;">Sponsored by</span></span></strong><span style="font-size: smaller;"><span style="font-family: Arial;"> </span></span><a href="http://www.pulsesupply.com"><span style="font-size: smaller;"><span style="font-family: Arial;">Pulse Supply</span></span></a></p>
            </td>
        </tr>
    </tbody>
</table>
<p>&nbsp;</p>
""" % (process_name, hostname, timestamp, message_body_html)

#############################
# Construct the message
#############################
text_part = MIMEText(text, 'plain')
html_part = MIMEText(html, 'html')
msg.attach(text_part)
msg.attach(html_part)

###############################
# Send the message
###############################
if smtp_port == "465":
	message = smtplib.SMTP_SSL(smtp_server, smtp_port, hostname)
else:
	message = smtplib.SMTP(smtp_server, smtp_port, hostname)
message.set_debuglevel(9)
if len(sys.argv[9]) > 1:
	message.login(smtp_user, smtp_pass)
message.sendmail(from_email, to_email, msg.as_string())
message.quit()
