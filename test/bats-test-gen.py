#!/usr/bin/env python

# This is a helper script to generate tests for Bats

import traceback
import yaml
import pprint

DOC_HEADER = """#!/usr/bin/env bats

root_dir=$PWD

load_lib() {
    local name="$1"
    load "$root_dir/test/test_helper/${name}/load.bash"
}

load_lib bats-support
load_lib bats-assert

# ----------------------------------------------------------------
"""



TEST_TEMPLATE = """
@test "{description} [{commands}]" {{
    run ./ap.sh {hostgroup} {playbook} {commands}
    {assert_type} "{expected}"
}}
"""


def generate_tests(suite):
    hostgroup = suite['hostgroup']
    assert_type = suite['type']
    tests = suite['tests']

    for test in tests:
        test = TEST_TEMPLATE.format(hostgroup=hostgroup, assert_type=assert_type, **test)
        print test


def write_testfile():
    print DOC_HEADER

    spec = open("spec.yml", "r")
    docs = yaml.load_all(spec)

    for suite in docs:
        generate_tests(suite)


def main():
    write_testfile()


if __name__ == "__main__":
    try:
        main()
    except BaseException:
        traceback.print_exc()