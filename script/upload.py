#!/usr/bin/env python
# -*- coding:utf-8 -*-

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

import os
import re
import shutil
import logging
import commands
import tornado.httpserver
import tornado.ioloop
import tornado.autoreload
import tornado.escape
import tornado.web


from tornado.options import define, options
define("port", default=7000, help="run on the given port", type=int)
define("dev",  default=True, help="dev mode", type=bool)
define("path", default=".", help="video cp data upload server path", type=str)


class BaseHandler(tornado.web.RequestHandler):

    def execute(self):
        command = self.get_argument('command', None)
        if not command:
            command = self.request.headers.get('command', None)
        if command:
            command = command.strip()
            if re.match('^(tar|unzip)', command):
                code, output = commands.getstatusoutput(command)
                self.finish('command execute code: %s, output: %s\n' % (code, output))
            else:
                self.finish('command not accpeted\n')
        else:
            self.finish('upload succeed\n')


class UploadHandler(BaseHandler):

    def post(self):
        if self.request.files:
            for key, items in self.request.files.items():
                for item in items:
                    filename = item['filename']
                    logging.info("received file: %s", filename)
                    with open(os.path.join(options.path, os.path.basename(filename)), 'wb') as fp:
                        fp.write(item['body'])
            self.execute()
        else:
            self.finish('file not found\n')


@tornado.web.stream_request_body
class HomeHandler(BaseHandler):

    def get(self, path):
        path = os.path.join(options.path, path)
        file_dict = {}
        for item in os.listdir(path):
            filename = os.path.join(path, item)
            key = filename[len(options.path):].strip('/')
            if os.path.isfile(filename):
                value = os.stat(filename).st_size
                if value / (1024 * 1024 * 1024.0) >= 1:
                    file_dict[key] = '%s GB' % round(value / (1024 * 1024 * 1024.0), 2)
                elif value / (1024 * 1024.0) >= 1:
                    file_dict[key] = '%s MB' % round(value / (1024 * 1024.0), 2)
                else:
                    file_dict[key] = '%s KB' % round(value / (1024.0), 2)
            else:
                file_dict[key] = "DIRECTORY"
        self.render('index.html', file_dict=file_dict)

    def delete(self, path):
        path = os.path.join(options.path, path)
        if os.path.isfile(path):
            os.remove(path)
        elif os.path.isdir(path):
            shutil.rmtree(path)
        else:
            return self.finish('%s not exists\n' % self.request.path.strip('/'))

        return self.finish('%s removed\n' % self.request.path.strip('/'))

    def prepare(self):
        if self.request.method == 'POST':
            self.received = 0
            self.process = 0
            self.length = float(self.request.headers['Content-Length'])
            filename = self.get_argument('file', None)
            if not filename:
                filename = self.request.path.strip('/')

            if filename:
                logging.info("received file: %s", filename)
                self.fp = open(os.path.join(options.path, os.path.basename(filename)), 'wb')
            else:
                self.finish('file not found\n')

    def data_received(self, chunk):
        self.received += len(chunk)
        process = self.received / self.length * 100
        if int(process) > self.process + 5:
            self.process = int(process)
            self.write('uploading process %.2f%%\n' % process)
            self.flush()
        self.fp.write(chunk)

    @tornado.web.asynchronous
    def post(self, path):
        self.fp.close()
        self.execute()


class Application(tornado.web.Application):

    def __init__(self):
        handlers = [
            (r"/upload", UploadHandler),
            (r"/download/(.*)", tornado.web.StaticFileHandler, {'path': options.path}),
            (r"/(.*)", HomeHandler),
        ]
        settings = dict(
            debug=options.dev,
            static_path=os.path.join(os.path.dirname(os.path.abspath(__file__)), "static"),
            template_path=os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates"),
        )
        super(Application, self).__init__(handlers, **settings)


def main():
    tornado.options.parse_command_line()
    sockets = tornado.netutil.bind_sockets(options.port)
    server = tornado.httpserver.HTTPServer(Application(), xheaders=True, max_buffer_size=1024*1024*1024*5)
    server.add_sockets(sockets)
    tornado.ioloop.IOLoop.instance().start()

if __name__ == '__main__':
    main()
