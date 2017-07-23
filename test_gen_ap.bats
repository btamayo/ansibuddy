#!/usr/bin/env bats

root_dir=$PWD

load_lib() {
    local name="$1"
    load "$root_dir/test/test_helper/${name}/load.bash"
}

load_lib bats-support
load_lib bats-assert

# ----------------------------------------------------------------


@test "Parse hostgroup correctly []" {
    run ./ap.sh bianca-blog.dev.app  
    assert_line "DEBUG: Passed hostgroup: bianca-blog.dev.app"
}


@test "Parse playbook name or path correctly []" {
    run ./ap.sh bianca-blog.dev.app site-a.yml 
    assert_line "DEBUG: Passed playbook name or path: site-a.yml"
}


@test "Parse playbook name or path correctly with two commands [check list-hosts]" {
    run ./ap.sh bianca-blog.dev.app site-a.yml check list-hosts
    assert_line "DEBUG: Passed playbook name or path: site-a.yml"
}


@test "Parse playbook name or path correctly with two commands [check list-hosts]" {
    run ./ap.sh bianca-blog.dev.app site-a.yml check list-hosts
    assert_line "DEBUG: Passed Commands: --syntax-check --list-hosts"
}


@test "Parse & convert one script command correctly [check]" {
    run ./ap.sh bianca-blog.dev.app  check
    assert_line "DEBUG: Passed Commands: --syntax-check"
}


@test "Parse & convert two script commands correctly [check list-hosts]" {
    run ./ap.sh bianca-blog.dev.app  check list-hosts
    assert_line "DEBUG: Passed Commands: --syntax-check --list-hosts"
}

