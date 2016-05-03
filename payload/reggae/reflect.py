from __future__ import (unicode_literals, division,
                        absolute_import, print_function)


from reggae.build import Build, DefaultOptions
from inspect import getmembers


def get_build(module):
    builds = [v for n, v in getmembers(module) if isinstance(v, Build)]
    assert len(builds) == 1
    return builds[0]


def get_default_options(module):
    opts = [v for n, v in getmembers(module) if isinstance(v, DefaultOptions)]
    assert len(opts) == 1 or len(opts) == 0
    return opts[0] if len(opts) else None
