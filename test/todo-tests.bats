#!/usr/bin/env bats

# Install Bats:
#  $ git clone https://github.com/sstephenson/bats.git
#  $ cd bats
#  $ ./install.sh $HOME

# This test needs to be ran from the project root dir


# $ git clone https://github.com/ztombol/bats-support test/test_helper/bats-support
# $ git clone https://github.com/ztombol/bats-assert test/test_helper/bats-assert

# Load a library from the `${BATS_TEST_DIRNAME}/test_helper' directory.
#
# Globals:
#   none
# Arguments:
#   $1 - name of library to load
# Returns:
#   0 - on success
#   1 - otherwise

# Run this test from root dir



# Test: no hostgroup, invalid filenames, invalid group names, options switched around, no extra args

# echo "DEBUG: Hosts: $hostgroup"
# echo "DEBUG: Found inventory file: $determined_inventoryfile"
# echo "DEBUG: Playbook file: $playbook_file"
# echo "DEBUG: additional options: " "$@"

# ./ap.sh bianca-blog.dev.app site.yml check
# ./ap.sh bianca-blog.dev.app site-a.yml check
# ./ap.sh bianca-blog.dev.app check -> Should use a site.yml even if it doesn't exist
# ./ap.sh bianca-blog.dev.app site-a.yml check list-hosts
# ./ap.sh bianca-blog.dev.app site-a.yml check -l webservers (normal ansible flags and args should prop)


# TESTS: 
# ./ap.sh 127.0.0.1 check
# ./ap.sh localhost check
# ./ap.sh localhost 
# ./ap.sh -i /inventory/path/name/hosts
# ./ap.sh -i /inventory/path/name
# ./ap.sh bianca-blog
# ./ap.sh bianca-blog.dev
# ./ap.sh bianca-blog.dev check
# ./ap.sh bianca-blog.dev playbooks/play.yml

# Multiple "remainder args"


# If it's not a found file, it might be a host address?
# e.g. 127.0.0.1, 54.123.1412.randomhost.com, localhost, digitaloceanbox

# ------------ PARSE TESTS --------------------



# ---------- ADVANCED PARSE TESTS ------------------------------------



# ---------- USABILITY & CONFIG TESTS --------------------------------



# ---------- NON-INTERFERENCE WITH ANSIBLE CONFIGS/BEHAVIORS ---------



# ---------- ERROR HANDLING TESTS ------------------------------------



# ---------- MORE EDGE CASES TESTS -----------------------------------






