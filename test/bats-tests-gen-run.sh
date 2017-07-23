#!/usr/bin/env bash

# Generate tests and write it to file

rm ./test_gen_ap.bats || :

cd test || exit

./bats-test-gen.py > ../test_gen_ap.bats

cd ../ || exit

chmod +x ./test_gen_ap.bats
./test_gen_ap.bats