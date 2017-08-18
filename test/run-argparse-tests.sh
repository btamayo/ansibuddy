#!/usr/bin/env bash

# run-argparse-tests.sh
# CI TEST RUNNER. 
# Tests argument persing
# 
# Defaults
# For parsing we don't need to create a temp directory since it's not related to dir structure
test_folder_name="test" # Where the generated testfile(s) will be placed
path_test_dir_full="$PWD/${test_folder_name}"

cd "$path_test_dir_full" || exit

# Generate tests, ignore generated tests since we don't need that in SCM
touch  "${path_test_dir_full}/generated_argparse_tests.gitignore.bats"
./bats-test-gen.py ./parse-spec.yml > "${path_test_dir_full}/generated_argparse_tests.gitignore.bats"

chmod +x "${path_test_dir_full}/generated_argparse_tests.gitignore.bats"

./generated_argparse_tests.gitignore.bats

code="$?"

exit $code