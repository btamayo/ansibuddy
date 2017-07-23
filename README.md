## Ansible Wrapper

**[WIP]**
I gave up and did this.
Ansible wrapper for my own projects. 



```bash
$ ./ap.sh <HOSTGROUP> <PLAYBOOK> [<COMMAND>] ...
```

`HOSTGROUP`:
	- General format(s): `<service>.<environment>` e.g. `<bianca-blog>.<production>`

`PLAYBOOK`:
	- path to playbook from root

`??? TODO`:
	- `setup`: sets up the machine
	- `install`: installs the app or service
	- `deploy`: configures components on the host(s) for the app

`COMMAND`:
	- check
	- list-hosts
	- help

`OPTIONS`: Other ansible-playbook options 

`ARGS`: Treat other args like other ansible-playbook args


### Other:

Development: Using nodemon (it won't watch files unless you specify, but you can use `rs` easily):

```shell
$ nodemon --exec "./ap.sh bianca-blog.dev.app check || true"
```

Development: Testing ./ap.sh


- Install bats first.
- Install the submodules

Generating tests:

The point of generating the Bats tests file is to generate it once, validate your tests by eye, and then run the tests.

- Write a spec in `test/spec.yml`
- Run `test/bats-test-gen.py` to print your tests to stdout
- Run `bats-test-gen-run.sh` to generate and run your tests automatically (uses a file called `test_gen_ap.bats`)


```shell
$  ./test_ap.bats
```