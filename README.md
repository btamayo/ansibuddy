## Ansibuddy: An Ansible-Playbook Wrapper

**[WIP] Do not use.**

**Background:** I gave up and did this. I was trying to avoid writing a wrapper script, but it seems like it makes things much easier.

Ansible wrapper for my own projects. This requires a specific directory structure.


## Usage

```bash
$ ./ap.sh <hostgroup> (<playbook> | -i <playbook-file>) [<command>...] ...
```

`hostgroup`:
	- General format(s): `<service>.<environment>.<host group>` e.g. `myblog.dev.docker`

`playbook`:
	- @TODO: Bianca Tamayo (Jul 22, 2017) - document precedence 

`playbook-file`: 
	- Path to a playbook file from root. Script does not check for file's existence.

`command`:
	- `check`: Run a syntax check (`ansible-playbook ... --syntax-check`)
	- `list-hosts`: List the affected hosts of this playbook run (`ansible-playbook ... --list-hosts`)
	- `help`: Display usage

`OPTIONS`: Other ansible-playbook options 

`ARGS`: Treat other args like other ansible-playbook args

## To Do:

- Proper argument parsing
- Move tests to `/test` dir
- Subcommands e.g.:
	- `setup`: sets up the machine
	- `install`: installs the app or service
	- `deploy`: configures components on the host(s) for the app


## Testing

- Install [bats](https://github.com/sstephenson/bats) first.
- Install the submodules if needed:
	- [bats-assert](https://github.com/ztombol/bats-assert)
	- [bats-support](https://github.com/ztombol/bats-support)

### Generating tests:

The point of generating the Bats tests file is to generate it once, validate your tests by eye, and then run the tests.

- Write a spec in `test/spec.yml`
- Run `test/bats-test-gen.py` to print your tests to stdout
- Run `bats-test-gen-run.sh` to generate and run your tests automatically (uses a file called `test_gen_ap.bats`)



```shell
$  ./test_ap.bats
```

## Other:

Snippet: Using nodemon (it won't watch files unless you specify, but you can use `rs` easily):

```shell
$ nodemon --exec "./ap.sh bianca-blog.dev.app check || true"
```

