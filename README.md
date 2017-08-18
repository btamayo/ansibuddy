

## Ansibuddy (a.k.a Ansibuddy!): An Ansible-Playbook Wrapper

[![Build Status](https://travis-ci.org/btamayo/ansibuddy.svg?branch=master)](https://travis-ci.org/btamayo/ansibuddy) [![stability-wip](https://img.shields.io/badge/stability-work_in_progress-lightgrey.svg)](https://github.com/btamayo/ansibuddy)

**[WIP] Do not use.**

**Background:** I gave up and did this. I was trying to avoid writing a wrapper script, but it seems like it makes things much easier.

Ansible wrapper for my own projects. This requires a specific directory structure.


## Usage

```bash
$ ./ap.sh (<hostgroup> | -i <inventory-file>) (<playbook> | -p <playbook-file>) [<command>...] -- [ansible-playbook-args]
```

#### `hostgroup`:
  - General format(s): `<service>.<environment>.<host group>` e.g. `myblog.dev.docker`

#### `inventory-file`:
  - Pass in an inventory file path. If the path is relative, it will treat it as relative from the current working directory and does not perform any searches or checks. Inventory files passed in with the `-i` flag always takes precedence over `<hostgroup>` and should not be passed together.

#### `playbook`:
  - @TODO: Bianca Tamayo (Jul 22, 2017) - document precedence 

#### `playbook-file`:
  - Pass in a playbook file path. If the path is relative, it will treat it as relative from the current working directory and does not perform any searches or checks. Playbook files passed in with the `-p` flag always takes precedence over `<playbook>` and should not be passed together.

#### `command`:
  - `check`: 
    - Run a syntax check (`ansible-playbook ... --syntax-check`)
  - `list-hosts`: 
    - List the affected hosts of this playbook run (`ansible-playbook ... --list-hosts`)
  - `help`: Display usage


`ansible-playbook-args`: 
  - Pass other ansible-playbook args. **You must separate between Ansibuddy arguments and ansible-playbook args using `--`**. 
  - If you pass in `--syntax-check`, `-i <hostfile>`,  `--inventory-file <hostfile>`, `-l <subset>`, `--limit <subset>` or `--list-hosts` through `ansible-playbook-args`, Ansibuddy will defer to those args instead.

For example, running "`bianca-blog.dev.docker site.yml -- -l webservers`" will give you `-l webservers` despite `docker` being provided as the `group name` into Ansibuddy:

```
./ap bianca-blog.dev.docker site.yml -- -l webservers

[EXEC]: ansible-playbook -i $PROJECT_ROOT/inventories/bianca-blog/dev/hosts $PROJECT_ROOT/playbooks/bianca-blog/site.yml -l webservers
```

However, using `/ap.sh bianca-blog.dev.docker site.yml` without the `-- -l webservers` parameter will limit it to the docker group hosts.

```
./ap.sh bianca-blog.dev.docker site.yml

[EXEC]: ansible-playbook -i $PROJECT_ROOT/inventories/bianca-blog/dev/hosts $PROJECT_ROOT/playbooks/bianca-blog/site.yml -l docker
```



## To Do:

- Integrate with [argbash](https://github.com/matejak/argbash)
- Subcommands e.g.:
    - `setup`: sets up the machine
    - `install`: installs the app or service
    - `deploy`: configures components on the host(s) for the app


## Testing

To test bash scripts, we use [bats](https://github.com/sstephenson/bats), then generate tests. This is to speed up both running the tests (as they're not generated every time), and writing them (simple YAML configuration).

### To run the tests:
- Install [bats](https://github.com/sstephenson/bats) first.
- Install the submodules if needed:
    - [bats-assert](https://github.com/ztombol/bats-assert)
    - [bats-support](https://github.com/ztombol/bats-support)

### Generating tests:

1. Write a spec in `test/spec.yml`.
2. Run `test/run-tests.sh`.

- `test/run-tests.sh` calls a Python script called `bats-test-gen.py` and relies on stdout and redirection to write to a file in a new, temporary directory called `".tmp-dir"` in the repo root. It copies over necessary files then runs the generated tests within.

#### Test spec

`./bats-test-gen.py` (the _bats test generator_) reads a YAML file and generates tests based on a template.

The YAML file can is passed in as the only CLI parameter to `./bats-test-gen.py`.

It must contain the following top level key(s):
- `script_name`: This is the script that the bats test will invoke with `run`
- `tests`: A YAML `list` object of `test`s that describes the each test to be generated

The following keys are optional and can be declared either in the top-level of the spec (where it will act as a default for all the tests), or in the `test` object itself:

**General:**
- `description`

**Test input params:**
- `hostgroup`
- `playbook`
- `commands`
- `shell`: Raw shell passed to the scripts. The presence of this key will activate the **Shell (Template 2)** template and is mutually exclusive with (`commands`, `playbook`, and `hostgroup`).

**Asserts and expects:**
- `assert_type`
- `partial`: (bool): This is a flag that corresponds to bats's (`--partial`). The generator only checks for the key's existence. `false`y values in YAML get convereted to `None` **strings** (truthy!) in Python at the moment. 
- `regex`: Overrides `expected` and adds `--regexp` flag to the test.


**Example test spec objects**:
```
- description: Parse hostgroup correctly
  playbook: site.yml
  commands: ""
  expected: "DEBUG: Passed hostgroup: bianca-blog.dev.app"
```

```
- description: Parse correctly & limit
  shell: 'bianca-blog.dev site.yml -- -l docker --list-hosts'
  expected: "Positionals: site.yml"
```


**Template 1: Parsed**

This template is in the following format:

```
@test "{description} [{hostgroup} {playbook} {commands}]" {{
    run ./{script_name} {hostgroup} {playbook} {commands} debug
    {assert_type} {partial} {regexflag} "{expected}"
}}"
```

**Template 2: Shell** 

This template is used when `shell` is present in the test spec.

```
@test "{description} [{shell}]" {{
    run ./{script_name} {shell}
    {assert_type} {partial} {regexflag} "{expected}"
}}
```

---

Stability badge(s) from [stability-badges](https://github.com/orangemug/stability-badges).
