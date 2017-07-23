#!/usr/bin/env bash

# Generate tests and write it to file

rm ./test_gen_ap.bats || :
cd test
./bats-test-gen.py > ../test_gen_ap.bats
cd ../
chmod +x ./test_gen_ap.bats
./test_gen_ap.bats