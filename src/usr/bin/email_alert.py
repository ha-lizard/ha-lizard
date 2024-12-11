#!/usr/bin/env python

import sys
import socket
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr

# Set a timeout for socket operations to avoid hanging if the network or DNS is down
socket.setdefaulttimeout(2)


def print_usage():
    """Print usage instructions for the script."""
    print("HA-Lizard email alert sender. Version 1.0 www.halizard.com")
    print("Pass in all command line arguments as follows")
    print(f"{sys.argv[0]} from_email to_email subject timestamp process_name message_body smtp_server smtp_port smtp_user smtp_pass")


def get_hostname():
    """Return the system hostname."""
    return socket.gethostname()


def construct_message(from_email, to_email, subject, message_body, process_name, hostname, timestamp):
    """
    Construct the email message with plain text and HTML parts.

    Args:
        from_email (str): Sender's email address.
        to_email (str): Receiver's email address.
        subject (str): Subject of the email.
        message_body (str): Body content of the email.
        process_name (str): Name of the process triggering the alert.
        hostname (str): System hostname.
        timestamp (str): Timestamp of the alert.

    Returns:
        MIMEMultipart: The email message object.
    """
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = formataddr(('HA-Lizard', from_email))
    msg['To'] = to_email

    # Message body - Text
    text = message_body

    # Message body - HTML
    message_body_html = "<br />".join(message_body.split("\n"))
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

    text_part = MIMEText(text, 'plain')
    html_part = MIMEText(html, 'html')
    msg.attach(text_part)
    msg.attach(html_part)

    return msg


def send_email(from_email, to_email, msg, smtp_server, smtp_port, smtp_user, smtp_pass):
    """
    Send the email using SMTP.

    Args:
        from_email (str): Sender's email address.
        to_email (str): Receiver's email address.
        msg (MIMEMultipart): The email message object.
        smtp_server (str): SMTP server address.
        smtp_port (str): SMTP server port.
        smtp_user (str): SMTP username for authentication.
        smtp_pass (str): SMTP password for authentication.
    """
    try:
        if smtp_port == "465":
            server = smtplib.SMTP_SSL(smtp_server, smtp_port)
        else:
            server = smtplib.SMTP(smtp_server, smtp_port)

        server.set_debuglevel(0)  # Set to 0 in production

        if smtp_user and smtp_pass:
            server.login(smtp_user, smtp_pass)

        server.sendmail(from_email, to_email, msg.as_string())
    except Exception as e:
        print(f"Failed to send email: {e}")
    finally:
        server.quit()


def main():
    """Main function to execute the script logic."""
    if len(sys.argv) != 11:
        print_usage()
        sys.exit(1)

    # Collect arguments from the command line
    from_email = sys.argv[1]
    to_email = sys.argv[2]
    subject = sys.argv[3]
    timestamp = sys.argv[4]
    process_name = sys.argv[5]
    message_body = sys.argv[6]
    smtp_server = sys.argv[7]
    smtp_port = sys.argv[8]
    smtp_user = sys.argv[9]
    smtp_pass = sys.argv[10]

    # Echo to stdout - halizard redirects to log
    print(f"Sending email from: {from_email}")
    print(f"Sending email to: {to_email}")
    print(f"Email Alert Subject: {subject}")
    print(f"Email Alert Timestamp: {timestamp}")
    print(f"Email Alert Process: {process_name}")
    print(f"Email Alert Message Content: {message_body}")
    print(f"Email Alert Message Hostname: {get_hostname()}")

    # Construct and send the email
    try:
        msg = construct_message(from_email, to_email, subject,
                                message_body, process_name, get_hostname(), timestamp)
        send_email(from_email, to_email, msg, smtp_server,
                   smtp_port, smtp_user, smtp_pass)
    except Exception as e:
        print(f"Error occurred: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
