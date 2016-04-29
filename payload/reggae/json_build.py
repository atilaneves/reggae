from __future__ import (unicode_literals, division,
                        absolute_import, print_function)


import json
import argparse


def get_json(module):
    from reggae.reflect import get_build, get_default_options
    build = get_build(module)
    default_opts = get_default_options(module)
    opts_json = [] if default_opts is None else [default_opts.jsonify()]

    return json.dumps(build.jsonify() + opts_json)


def main():
    parser = argparse.ArgumentParser(description='oh hello')
    parser.add_argument('--dict', type=json.loads, default=dict())
    parser.add_argument('project_path', help='The project path')
    args = parser.parse_args()

    from reggae import set_user_vars
    set_user_vars(args.dict)

    import sys
    sys.path.append(args.project_path)
    import reggaefile
    print(get_json(reggaefile))


if __name__ == '__main__':
    main()
