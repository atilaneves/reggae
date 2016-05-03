from __future__ import (unicode_literals, division,
                        absolute_import, print_function)


class Target(object):
    def __init__(self, outputs, cmd="", deps=[], implicits=[]):
        self.outputs = _listify(outputs)
        self.cmd = _jsonifiable(cmd, ShellCommand)
        self.deps = dependencies(deps, FixedDependencies)
        self.implicits = dependencies(implicits, FixedDependencies)
        self.optional = False

    def jsonify(self):
        ret = {'type': 'fixed',
               'outputs': self.outputs,
               'command': self.cmd.jsonify(),
               'dependencies': self.deps.jsonify(),
               'implicits': self.implicits.jsonify()}

        if self.optional:
            ret['optional'] = True

        return ret


def _listify(arg):
    return arg if isinstance(arg, list) else [arg]


def _jsonifiable(arg, cls):
    return arg if hasattr(arg, 'jsonify') else cls(arg)


def dependencies(arg, cls):
    from reggae.rules import DynamicDependencies, target_concat

    if isinstance(arg, Dependencies):
        return arg

    if isinstance(arg, list) and len(arg) > 1 and \
       any(isinstance(x, DynamicDependencies) for x in arg):
        return target_concat(*arg)

    if isinstance(arg, list) and len(arg) == 1:
        return dependencies(arg[0], cls)

    return cls(arg)


class ShellCommand(object):
    def __init__(self, cmd=''):
        self.cmd = cmd

    def jsonify(self):
        if self.cmd == '':
            return {}
        return {'type': 'shell', 'cmd': self.cmd}


class Dependencies(object):
    pass


class FixedDependencies(Dependencies):
    def __init__(self, deps):
        self.deps = _listify(deps)

    def jsonify(self):
        return {'type': 'fixed', 'targets': [t.jsonify() for t in self.deps]}


class Build(object):
    def __init__(self, *targets):
        self.targets = targets

    def jsonify(self):
        return [t.jsonify() for t in self.targets]


class DefaultOptions(object):
    def __init__(self, **kwargs):
        self.kwargs = kwargs

    def jsonify(self):
        json = self.kwargs.copy()
        json['type'] = 'defaultOptions'
        return json


def optional(tgt):
    tgt.optional = True
    return tgt
