#!/usr/bin/env python

# This is a helper script to generate tests for Bats

import argparse
import pprint
import traceback
import yaml

TEMPLATE_KEYS = ['script_name', 'description', 'hostgroup', 'playbook', 'commands', 'assert_type', 'partial', 'regexflag', 'expected']

DOC_HEADER = """#!/usr/bin/env bats

load_lib() {
    local name="$1"
    load "test_helper/${name}/load"
}

load_lib bats-support
load_lib bats-assert

# ----------------------------------------------------------------
"""

TEST_TEMPLATE = """@test "{description} [{hostgroup} {playbook} {commands}]" {{
    run ./{script_name} {hostgroup} {playbook} {commands} debug
    {assert_type} {partial} {regexflag} "{expected}"
}}
"""

def override_key(overrider, overriden):
    for key in overrider:
        if key in overriden:
            overriden[key] = overrider[key]

    for req in TEMPLATE_KEYS:
        if req not in overrider:
            overrider[req] = overriden[req] if req in overriden else ""

    return overrider


def generate_tests(suite):
    tests = suite['tests']

    for test in tests:
        if 'partial' in test:
            test['partial'] = "--partial"

        if 'regex' in test:
            test['regexflag'] = '--regexp'
            test['expected'] = test['regex']

        test = override_key(test, suite) # Override the rest

        test = TEST_TEMPLATE.format(**test)
        print test


def print_testfile(specfile):
    with open(specfile, "r") as spec:
        docs = yaml.load_all(spec)

        # Print the header
        print DOC_HEADER

        for suite in docs:
            generate_tests(suite)



def main():
    parser = argparse.ArgumentParser(description='Read a spec file')
    parser.add_argument('spec', metavar='spec', help='Path to spec yml file')
    args = parser.parse_args()
    print_testfile(args.spec)


if __name__ == "__main__":
    try:
        main()
    except BaseException:
        traceback.print_exc()