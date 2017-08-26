## Ansibuddy: An Ansible-Playbook Wrapper


[![Build Status](https://travis-ci.org/btamayo/ansibuddy.svg?branch=master)](https://travis-ci.org/btamayo/ansibuddy) [![stability-wip](https://img.shields.io/badge/stability-work_in_progress-lightgrey.svg)](https://github.com/btamayo/ansibuddy)

**[WIP] Do not use.**


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

## Possible Future Enhancements

- Integrate with [argbash](https://github.com/matejak/argbash)
- Subcommands e.g.:
    - `setup`: sets up the machine
    - `install`: installs the app or service
    - `deploy`: configures components on the host(s) for the app



## Testing

See [test/README.md](test/README.md)


---

Stability badge(s) from [stability-badges](https://github.com/orangemug/stability-badges).
