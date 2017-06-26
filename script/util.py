#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

import logging
import logging.handlers


def Logger(filename=None, name=None, disable=False, level='INFO'):
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


class DefaultDict(Dict):

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
