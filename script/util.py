#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import json
import time
import logging
import logging.handlers
from tornado.log import LogFormatter


def str2int(str_time):
    return int(time.mktime(time.strptime(str_time, "%Y-%m-%d %H:%M:%S")))


def int2str(int_time):
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(int_time))


class Logger(logging.Logger):

    def __init__(self, filename=None, name='root', level='INFO', stream=True):
        level = getattr(logging, level.upper())
        super(Logger, self).__init__(name, level)
        if stream:
            hdlr = logging.StreamHandler()
            hdlr.setFormatter(LogFormatter())
            self.addHandler(hdlr)

        if filename:
            hdlr = logging.handlers.WatchedFileHandler(filename=filename, mode='a', encoding='utf-8')
            hdlr.setFormatter(LogFormatter(color=False))
            self.addHandler(hdlr)


class JSONDecoder(json.decoder.JSONDecoder):
    '''使用json.loads时默认的key和value都是unicode类型
    如果某些地方的key和value必须使用utf-8格式
    则可使用json.loads(data, cls=JSONDecoder)
    '''

    def __init__(self, **kwargs):
        kwargs['object_hook'] = self.__decode_dict
        super(JSONDecoder, self).__init__(**kwargs)

    def _decode_list(self, data):
        rv = []
        for item in data:
            if isinstance(item, unicode):
                item = item.encode('utf-8')
            elif isinstance(item, list):
                item = self._decode_list(item)
            elif isinstance(item, dict):
                item = self.__decode_dict(item)
            rv.append(item)
        return rv

    def __decode_dict(self, data):
        rv = {}
        for key, value in data.iteritems():
            if isinstance(key, unicode):
                key = key.encode('utf8')
            if isinstance(value, unicode):
                value = value.encode('utf8')
            elif isinstance(value, list):
                value = self._decode_list(value)
            elif isinstance(value, dict):
                value = self.__decode_dict(value)
            rv[key] = value
        return rv


class JSONEncoder(json.encoder.JSONEncoder):
    '''针对某些不能序列化的类型如datetime
    使用json.dumps(data, cls=JSONEncoder)
    '''

    def default(self, obj):
        if isinstance(obj, (datetime.datetime, datetime.date, bson.ObjectId)):
            return str(obj)
        elif isinstance(obj, set):
            return list(obj)
        else:
            return super(JSONEncoder, self).default(obj)


class Dict(dict):
    '''将字段改为通过属性访问
    '''

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


class DefaultDict(Dict):
    '''类似connections.defaultdict
    '''

    def __init__(self, default_factory=None, *args, **kwargs):
        if default_factory is not None and not hasattr(default_factory, '__call__'):
            raise TypeError('first argument must be callable')
        super(DefaultDict, self).__init__(*args, **kwargs)
        self.__dict__['default_factory'] = default_factory

    def __missing__(self, key):
        if self.__dict__['default_factory'] is None:
            raise KeyError(key)
        self[key] = self.__dict__['default_factory']()
        return self[key]

    def __len__(self):
        return super(DefaultDict, self).__len__()

    def __reduce__(self):
        if self.__dict__['default_factory'] is None:
            args = tuple()
        else:
            args = (self.__dict__['default_factory'], )
        return type(self), args, None, None, self.iteritems()

    def copy(self):
        return self.__copy__()

    def __copy__(self):
        return type(self)(self.__dict__['default_factory'], self)

    def __deepcopy__(self, memo):
        return type(self)(self.__dict__['default_factory'], copy.deepcopy(self.items()))

    def __repr__(self):
        return 'DefaultDict(%s, %s)' % (self.__dict__['default_factory'], Dict.__repr__(self))
