from __future__ import (unicode_literals, division,
                        absolute_import, print_function)


from reggae.build import (Target, Build, DefaultOptions, optional)  # noqa
from reggae.rules import (executable, link, object_files, static_library,  # noqa
                          scriptlike, target_concat)

user_vars = dict()
options = dict()


def set_options(opts):
    global options, user_vars
    options = opts
    user_vars = opts["userVars"]
