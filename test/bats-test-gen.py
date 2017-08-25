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

def override_key(test, suite):
    for req in TEMPLATE_KEYS:
        if req not in test:
            test[req] = suite[req] if req in suite else ''

    return test


def generate_tests(suite):
    def format_test(test):
        desc = '%s %s.%s' % (test['description'], str(count), str(subcount))
        test['description'] = desc
        test = override_key(test, suite) # Override the rest
        # test = dict({k: v for k, v in test.items() if v is not None})
        return template.format(**test)

    count = 0
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
        else:
            expected = ''

        # For each 'assert/expect' statement, create a test
        subcount = 0

        # Save original description
        odesc = test['description']

        if len(asserts_list) > 0:
            for item in asserts_list:
                test['expected'] = item
                print format_test(test)
        else:
                print format_test(test)


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