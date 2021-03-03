#!/usr/bin/env python3
from __future__ import print_function
import argparse
import os
import yaml

KEY_SEPARATOR = '.'


def load_config(conffile):
    if not os.path.exists(conffile):
        return None
    with open(conffile, 'r') as f:
        return yaml.safe_load(f)


def iteritems_nested(d):
    def fetch(suffixes, v0):
        if isinstance(v0, dict):
            for k, v in v0.items():
                for i in fetch(suffixes + [k], v):  # "yield from" in python3.3
                    yield i
        else:
            yield (suffixes, v0)

    return fetch([], d)


def flatten_dict(d, key_separator):
    return dict((key_separator.join(ks), v) for ks, v in iteritems_nested(d))


def convert(obj):
    if isinstance(obj, bool):
        return str(obj).lower()
    if isinstance(obj, (list, tuple)):
        return [convert(item) for item in obj]
    if isinstance(obj, dict):
        return {convert(key): convert(value) for key, value in obj.items()}
    return obj


def main():
    parser = argparse.ArgumentParser(description='Load configuration yaml and converts to flat [k,v] settings '
                                                 'dictionary to be put into environment variables.')
    parser.add_argument('--source', type=str, help='Source config file')
    args = parser.parse_args()
    if not args.source:
        exit(parser.print_usage())
    else:
        source = args.source

    cfg = load_config(source)
    cfg_kv_map = flatten_dict(cfg, KEY_SEPARATOR)
    print("\n".join(['%s=%s' % (key, value) for (key, value) in convert(cfg_kv_map).items()]))


if __name__ == '__main__':
    main()
