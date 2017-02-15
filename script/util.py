#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

import logging
import logging.handlers
from email import encoders
from email.mime.application import MIMEApplication
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.header import Header
from email.utils import COMMASPACE, formatdate
from mimetools import Message



def Logger(filename=None, name=None, disable=False, level='DEBUG'):
    logger = logging.getLogger(name)
    from tornado.log import LogFormatter
    logger.setLevel(getattr(logging, level.upper()))
    if not any(map(lambda x: isinstance(x, logging.StreamHandler), logger.handlers)):
        channel = logging.StreamHandler()
        channel.setFormatter(LogFormatter())
        logger.addHandler(channel)
    if filename:
        channel = logging.handlers.WatchedFileHandler(filename=filename, mode='a', encoding='utf-8', delay=True)
        channel.setFormatter(LogFormatter(color=False))
        logger.addHandler(channel)
    return logger

def mail(sender, receivers, title=None, content=None, files=None, **kwargs):
    if not isinstance(receivers, list):
        receivers = [receivers]
    msg = MIMEMultipart()
    if files:
        if isinstance(files, (str, unicode)):
            files = [files]
        if isinstance(files, list):
            tmp = {}
            for filename in files:
                if os.path.exists(filename):
                    tmp[filename] = open(filename, 'rb').read()
            files = tmp
        for key, value in files.items():
            part = MIMEText(value, 'base64', 'utf-8')
            part['Content-Type'] = 'application/octet-stream'
            part['Content-Disposition'] = 'attachment; filename="%s"' % os.path.basename(key)
            msg.attach(part)

    if content:
        part = MIMEText(content, 'html', 'utf-8')
        msg.attach(part)

    msg['from'] = sender
    msg['to'] = COMMASPACE.join(receivers)
    msg['date'] = formatdate(localtime=True)
    msg['subject'] = title

    if kwargs.get('cc'):
        if not isinstance(kwargs['cc'], list):
            kwargs['cc'] = [kwargs['cc']]
        msg['cc'] = COMMASPACE.join(kwargs['cc'])

    if kwargs.get('smtp') and kwargs.get('username') and kwargs.get('password'):
        smtp = smtplib.SMTP()
        smtp.connect(kwargs['smtp'])
        smtp.login(kwargs['username'], kwargs['password'])
    else:
        smtp = smtplib.SMTP('localhost')
    smtp.sendmail(sender, receivers, msg.as_string())
    smtp.quit()


class Dict(dict):

    def __init__(self, *args, **kwargs):
        super(Dict, self).__init__(*args, **kwargs)
        for key in self:
            if isinstance(self[key], dict):
                self[key] = Dict(self[key])
            elif isinstance(self[key], list):
                self[key] = self.__decode_list(self[key])

    def __decode_list(self, data):
        for i, item in enumerate(data):
            if isinstance(item, dict):
                data[i] = Dict(item)
            elif isinstance(item, list):
                data[i] = self.__decode_list(item)
        return data

    def __getattr__(self, key):
        try:
            return self[key]
        except:
            return None
        # except KeyError as k:
            # raise AttributeError, k

    def __setattr__(self, key, value):
        self[key] = value

    def __delattr__(self, key):
        try:
            del self[key]
            return True
        except:
            return False
        # except KeyError as k:
            # raise AttributeError, k

