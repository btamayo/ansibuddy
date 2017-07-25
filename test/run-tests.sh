#!/usr/bin/env bash

# run-tests.sh
# CI TEST RUNNER
# Generate a separate folder and copy all examples from sample directory into it.
# Copy necessary scripts into folder.
# This does not test intalling the scripts.
# 
# Copying instead of linking to match final usage better later.

# Defaults

# RUN FROM PROJECT ROOT

ap_script_name="ap.sh"
temp_dir_name=".tmp-test"
example_dir_name="samples"

rm -rf ${temp_dir_name} || true
mkdir ${temp_dir_name}

path_temp_dir_full="$PWD/${temp_dir_name}"

cp ${ap_script_name} "${path_temp_dir_full}/"
cp -r ./test/test_helper "${path_temp_dir_full}/"



# Generate tests
touch  "${path_temp_dir_full}/generated_tests.bats"
./test/bats-test-gen.py ./test/spec.yml > "${path_temp_dir_full}/generated_tests.bats"

chmod +x "${path_temp_dir_full}/generated_tests.bats"


while IFS= read -d $'\0' -r foldername ; do 
    cp -r "$foldername" "${path_temp_dir_full}/"
done < <(find ./${example_dir_name} -mindepth 1 -maxdepth 1 -type d -print0 -name "example-*")

# CD to ensuure the rel paths are right
cd "${path_temp_dir_full}" || exit
./generated_tests.bats

code="$?"

rm -rf "${path_temp_dir_full}"
exit $code