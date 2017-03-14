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
import uuid

from tornado.options import define, options
define("port", default=8080, help="run on the given port", type=int)
define("dev",  default=True, help="dev mode", type=bool)


@tornado.web.stream_request_body
class StreamHandler(tornado.web.RequestHandler):

    def prepare(self):
        self.length = float(self.request.headers['Content-Length'])
        self.received = 0
        self.process = 0
        filename = self.request.headers.get('file', uuid.uuid4().hex)
        self.fp = open(os.path.basename(filename), 'wb')

    def data_received(self, chunk):
        self.received += len(chunk)
        process = self.received / self.length * 100
        if int(process) > self.process:
            self.process = int(process)
            self.write('uploading process %.2f%%\n' % process)
        self.fp.write(chunk)

    @tornado.web.asynchronous
    def post(self):
        self.fp.close()
        self.finish('succeed\n')


class UploadHandler(tornado.web.RequestHandler):

    def post(self):
        ip = self.request.headers['X-Real-Ip'].split(",")[0] if 'X-Real-Ip' in self.request.headers else self.request.remote_ip
        if self.request.files:
            for key, items in self.request.files.items():
                for item in items:
                    logging.info("received file: %s", item['filename'])
                    with open(os.path.basename(item['filename']), 'wb') as fp:
                        fp.write(item['body'])
            self.finish('succeed')
        else:
            self.finish('filename not found')

    def execute(self):
        command = self.request.headers.get('command', None)
        if command:
            logging.info(cmd)
            code, output = commands.getstatusoutput(cmd)
            logging.info("command execute code: %s, output: %s", code, output)
            self.finish('command execute result: %s' % output)
        else:
            self.finish('succeed')


class HomeHandler(tornado.web.RequestHandler):

    def get(self):
        files = filter(lambda x: os.path.isfile(x), os.listdir('.'))
        file_dict = dict(map(lambda x: (x, os.stat(x).st_size), files))
        for key, value in file_dict.items():
            if value / (1024 * 1024 * 1024.0) >= 1:
                file_dict[key] = '%s GB' % round(value / (1024 * 1024 * 1024.0), 2)
            elif value / (1024 * 1024.0) >= 1:
                file_dict[key] = '%s MB' % round(value / (1024 * 1024.0), 2)
            else:
                file_dict[key] = '%s KB' % round(value / (1024.0), 2)
        self.render('index.html', file_dict=file_dict)


class Application(tornado.web.Application):

    def __init__(self):
        handlers = [
            (r"/stream", StreamHandler),
            (r"/upload", UploadHandler),
            (r"/.*", HomeHandler),
        ]
        settings = dict(
            debug=options.dev,
            static_path=os.path.join(os.path.dirname(__file__), "."),
            template_path=os.path.join(os.path.dirname(__file__), "templates"),
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
