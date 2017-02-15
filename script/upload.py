#!/usr/bin/env python
# -*- coding:utf-8 -*-

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

import os
import tornado.httpserver
import tornado.ioloop
import tornado.autoreload
import tornado.escape
import tornado.web
import uuid
import logging
import commands

from tornado.options import define, options
define("port", default=8080, help="run on the given port", type=int)
define("dev",  default=True, help="dev mode", type=bool)


#@tornado.web.stream_request_body
class HomeHandler(tornado.web.RequestHandler):

    def prepare(self):
        ip = self.request.headers['X-Real-Ip'].split(",")[0] if 'X-Real-Ip' in self.request.headers else self.request.remote_ip
        self.filename = self.request.headers.get('filename', None)
        if self.request.files:
            for key, items in self.request.files.items():
                for item in items:
                    logging.info("received file: %s", item['filename'])
                    with open(os.path.basename(item['filename']), 'wb') as fp:
                        fp.write(item['body'])
            self.execute()
        elif self.filename:
            logging.info("received file: %s", self.filename)
            self.fp = open(os.path.basename(self.filename), 'wb')
        else:
            self.finish({'err': 1, 'msg': 'filename not found'})

    def execute(self):
        command = self.request.headers.get('command', None)
        if command:
            logging.info(cmd)
            code, output = commands.getstatusoutput(cmd)
            logging.info("command execute code: %s, output: %s", code, output)
            self.finish({'err': code, 'msg': output})
        else:
            self.finish({'err': 0})

    def data_received(self, chunk):
        self.fp.write(chunk)

    def post(self):
        self.fp.close()
        self.execute()


class Application(tornado.web.Application):

    def __init__(self):
        handlers = [
            (r"/.*", HomeHandler),
        ]
        settings = dict(
            debug=options.dev,
        )
        tornado.web.Application.__init__(self, handlers, **settings)


def main():
    tornado.options.parse_command_line()
    port = int(options.port)
    sockets = tornado.netutil.bind_sockets(port)
    server = tornado.httpserver.HTTPServer(Application(), xheaders=True, max_buffer_size=1024*1024*1024*5)
    server.add_sockets(sockets)
    tornado.ioloop.IOLoop.instance().start()

if __name__ == '__main__':
    main()

