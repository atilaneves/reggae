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


def get_dependencies(module):
    from modulefinder import ModuleFinder
    import os

    finder = ModuleFinder()
    finder.run_script(module)
    all_module_paths = [os.path.abspath(m.__file__) for
                        m in finder.modules.values() if m.__file__ is not None]

    def is_in_same_path(p):
        return p and os.path.dirname(p).startswith(os.path.dirname(module))

    return [x for x in all_module_paths if is_in_same_path(x) and x != module]
