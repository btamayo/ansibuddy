## Ansibuddy: An Ansible-Playbook Wrapper


[![Build Status](https://travis-ci.org/btamayo/ansibuddy.svg?branch=master)](https://travis-ci.org/btamayo/ansibuddy) [![stability-wip](https://img.shields.io/badge/stability-work_in_progress-lightgrey.svg)](https://github.com/btamayo/ansibuddy)

Ansibuddy is a CLI tool that simplifies running ansible-playbook. It takes in simple CLI commands and runs the equivalent ansible-playbook command, including it's flags and parameters.

## Purpose

- todo


## Install
```
$ brew update && brew tap btamayo/cli
$ brew install ansibuddy
```


## Usage

Ansibuddy supports both simple project structures (e.g. one env, app, or project in one ansible project) and complex ones (multiple projects and environments in the same ansible directory).

For all project structures, the basic usage is:

```shell
$ ansibuddy [hosts] [playbook]
```

The `hosts` argument can mean different things _semantically_, depending on how your project is structured:

For example, for more complex project directories, it _could_ be in the form of:
- `<service_name>.<environment>.<hostgroups>` (e.g. `myblog.dev.dbservers`)

While for simpler directory structures, it could just be:
- `<environment>` (e.g. `dev`)

Ansibuddy works by looking through the directory structure in a specific order to find the right `hosts` or `inventory` file, playbook file, and appends appropriate limiting (`-l`) groups. It makes no assumptions about your content organization and will search with a pre-determined logic.

You can also use the `-i` and the `-p` arguments to explicitly provide a path for an inventory file and/or a playbook file respectively.

### Simple directory structure:

Let's say your directory structure is similar to the one Ansible has on their [best practices page](http://docs.ansible.com/ansible/latest/playbooks_best_practices.html#content-organization) (irrelevant directories are omitted for brevity):

```
production                # inventory file for production servers
staging                   # inventory file for staging environment

site.yml                  # master playbook
webservers.yml            # playbook for webserver tier
dbservers.yml             # playbook for dbserver tier
```

Here, the hosts and playbooks are both in the root directory.


From the root directory, we can run ansibuddy to help us simplify ansible-playbook cli inputs. Output marked `[EXEC]` shows you what ansibuddy determines the equivalent ansible-playbook command is.

```shell
# Just by itself

$ ansibuddy
[EXEC]: ansible-playbook site.yml

# Here you see that it falls back to site.yml, and it does not know 
# which inventory file to pass in. (So if you defined a default 
# inventory file in `ansible.cfg`, `ansible-playbook` will use that.
```

```
# Choosing an inventory file
# Remember that the `host group` is the first parameter

$ ansibuddy production
[EXEC]: ansible-playbook -i ./production site.yml
                              # ^^^ Ansibuddy sees that 'production' exists but can't 
                              # determine a playbook from it, so falls back to site.yml
```

Let's say you want to use the `production` inventory file (_environment_), and limit to the `docker` servers:

```shell
$ ansibuddy production.docker

[EXEC]: ansible-playbook -i ./production site.yml -l docker
                               # ^^^ Ansibuddy sees that 'production' exists, 
                               # picks it as a host, then adds the -l docker. 
                               # It cannot find a suitable playbook 
                               # except for the fallback, `site.yml`


# If we run the same command with the `-x` (debug) flag, 
# it shows us the search paths (note that in the actual 
# debug output, the paths are shown in full, they're omitted 
# here and represented as `./` for brevity:

DEBUG: Determining correct inventory from 'production.docker'
DEBUG: Inventory file not found in: ./production/hosts
DEBUG: ./production is not a directory
DEBUG: Found inventory file in ./production
DEBUG: Found service name: production
DENUG: Found env name: docker
DEBUG: <parent>.<child> hostgroups are:
docker
DEBUG: Length of grp arr: 1
INFO: Limiting to host groups [docker]
DEBUG: 3. No playbook provided at all.
DEBUG: Playbook not found in: ./playbooks/production.yml
DEBUG: Playbook not found in: ./playbooks/production.yaml
DEBUG: Playbook not found in: ./playbooks/production
DEBUG: Playbook not found in: ./playbooks/production/production


[EXEC]: ansible-playbook -i ./production site.yml -l docker
```

Ansibuddy tries to find a playbook based on "`production`" but since it cannot safely find an existing one, it defaults to `site.yml`.

### Adding a playbook:

The playbook is the second positional argument.

```
$ ansibuddy production.docker webservers.yml

[EXEC]: ansible-playbook -i ./production ./webservers.yml -l docker
```

<details><summary>The debug output for the above command:</summary>

```shell 
$ ansibuddy production.docker -x


Positionals:  | PositionalInventoryHostgroup: production.docker | PositionalPlaybook:  | Inventory file path:  | Playbook file path:  | Additional options:
Flag List hosts: false
Flag Debug mode: true
Flag Check syntax: false

DEBUG: Base path is: /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1

DEBUG: Passed Commands:

DEBUG: Determining correct inventory from 'production.docker'
DEBUG: Inventory file not found in: /production/hosts
DEBUG: /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1/production is not a directory
DEBUG: Found inventory file in /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1/production
DEBUG: Found service name: production
DENUG: Found env name: docker
DEBUG: <parent>.<child> hostgroups are:
docker
DEBUG: Length of grp arr: 1
INFO: Limiting to host groups [docker]
DEBUG: 3. No playbook provided at all.
DEBUG: Playbook not found in: /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1/playbooks/production.yml
DEBUG: Playbook not found in: /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1/playbooks/production.yaml
DEBUG: Playbook not found in: /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1/playbooks/production
DEBUG: Playbook not found in: /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1/playbooks/production/production
[EXEC]: ansible-playbook -i /Users/btamayo/Development/ansibuddy/samples/ansible-best-practices-1/production site.yml -l docker

[EXEC]: ansible-playbook -i ./production site.yml -l docker

Continue?
```
</details>

## Testing

See [test/README.md](test/README.md)


---

Stability badge(s) from [stability-badges](https://github.com/orangemug/stability-badges).
