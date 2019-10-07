""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt

UCI Bottle Plugin
"""
from inspect import signature
from bottle import PluginError
from plugins.uci import Uci


class UCIPlugin:
    """ pass a handle to uci to routes who need it """

    name = 'uci'
    api = 2

    def __init__(self, identifier="uci", config_dir="/etc/config"):
        self.config_dir = config_dir
        self.uci = Uci(self.config_dir)
        self.identifier = identifier

    def setup(self, app):
        """ Make sure that other installed plugins are for different directories"""
        for other in app.plugins:
            if not isinstance(other, UCIPlugin):
                continue
            if other.config_dir == self.config_dir:
                raise PluginError("Found another uci plugin")
            if other.name == self.name:
                self.name += '_%s' % self.config_dir

    def apply(self, callback, _):
        """ called on each route activation """
        if self.identifier not in signature(callback).parameters:
            return callback

        def wrapper(*args, **kwargs):
            """ adding our Uci object when requested - called on each request"""
            kwargs[self.identifier] = self.uci
            return callback(*args, **kwargs)

        # Replace the route callback with the wrapped one.
        return wrapper


UCI_PLUGIN = UCIPlugin()
UCI_ROM_PLUGIN = UCIPlugin("uci_rom", "/rom/etc/config")
