## Testing

To test bash scripts, we use [bats](https://github.com/bats-core/bats-core), then generate tests. This is to speed up both running the tests (as they're not generated every time), and writing them (simple YAML configuration).

### To run the tests:
- Install [bats](https://github.com/bats-core/bats-core) first.
- Install the submodules if needed:
    - [bats-assert](https://github.com/ztombol/bats-assert)
    - [bats-support](https://github.com/ztombol/bats-support)

```shell
$ ./test/run-tests.sh 
$ ./test/run-argparse-tests.sh
```

### Generating tests:

1. Write a spec in `test/spec.yml`.
2. Run `test/run-tests.sh`.

- `test/run-tests.sh` calls a Python script called `bats-test-gen.py` and relies on stdout and redirection to write to a file in a new, temporary directory called `".tmp-dir"` in the repo root. It copies necessary files then runs the generated tests within.

#### Test spec

`./bats-test-gen.py` (the _bats test generator_) reads a YAML file and generates tests based on a template.

The YAML file path is passed in as the only CLI parameter to `./bats-test-gen.py`.

It must contain the following top level key(s):
- `script_name`: This is the script that the bats test will invoke with `run`
- `tests`: A YAML `list` object of `test`s that describes the each test to be generated

The following keys can be declared either in the top-level of the spec (where it will act as a default for all the tests), or in the `test` object itself which will override the default for that test. Keys must be declared except flags/booleans.

**Note:** At the moment, generator python script (`bats-test-gen.py`) only checks for the key's existence. `false`y values in YAML get convereted to `"None"` **strings** (truthy!) in Python. 

**General:**
- `description`

**Test input params:**
- `hostgroup`
- `playbook`
- `commands`
- `shell`: Raw shell passed to the scripts. The presence of this key will activate the **Shell (Template 2)** template and is mutually exclusive with (`commands`, `playbook`, and `hostgroup`).

**Asserts and expects:**
- `assert_type`
- `partial`: (bool): This is a flag that corresponds to bats's (`--partial`). 
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