from __future__ import (unicode_literals, division,
                        absolute_import, print_function)


from reggae.build import (Target, Build, DefaultOptions, optional)  # noqa
from reggae.rules import (executable, link, object_files, static_library,  # noqa
                          scriptlike, target_concat)

user_vars = dict()


def set_user_vars(new_vars):
    global user_vars
    user_vars = new_vars
