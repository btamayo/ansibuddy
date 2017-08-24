#!/usr/bin/env python

# This is a helper script to generate tests for Bats

import argparse
import pprint
import traceback
import yaml

TEMPLATE_KEYS = ['shell', 'script_name', 'description', 'hostgroup', 'playbook', 'commands', 'assert_type', 'partial', 'regexflag', 'expected']

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
    run ./{script_name} {hostgroup} {playbook} {commands} --debug --no-exec
    {assert_type} {partial} {regexflag} "{expected}"
}}
"""

# For script + <raw shell> (i.e. argparsing)
TEST_TEMPLATE_RAW = """@test "{description} [{shell}]" {{
    run ./{script_name} {shell} --debug --no-exec
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
    count = 0 # Since bats needs a unique desc each test
    tests = suite['tests'] # 'tests' key in spec
    
    # Update the manual flags from yml -> bats
    # This is declared top-level in the spec file and can be overriden by any indivudal test
    if 'partial' in suite:
        suite['partial'] = '--partial'

    for test in tests:
        count += 1
        template = TEST_TEMPLATE_RAW if 'shell' in test else TEST_TEMPLATE

        if 'partial' in test:
            test['partial'] = "--partial"

        if 'regex' in test:
            test['regexflag'] = '--regexp'
            test['expected'] = test['regex']

        # @TODO: Bianca Tamayo (Aug 21, 2017) - 
        # Not sure if bats/bats-assert supports multiple 'expected' statements?
        # I don't see it in the docs
        # However, we can make the generator spit out multiple
        # unit tests if it encounters multiple 'expected' keys
        # in a single test (in a list)

        asserts_list = []
        if 'expected' in test:
            # Take the string and assign it to new list
            if isinstance(test['expected'], basestring):
                asserts_list.append(test['expected'])
            else:
                asserts_list = test['expected']

        # For each 'assert/expect' statement, create a test
        # Save original description
        odesc = test['description']
        subcount = 0
        for item in asserts_list:
            subcount += 1
            desc = '%s %s.%s' % (odesc, str(count), str(subcount))
            test['expected'] = item
            test['description'] = desc
            formatted_test = override_key(test, suite) # Override the rest
            formatted_test = template.format(**test)
            print formatted_test


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