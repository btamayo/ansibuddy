## Example 1

In this example, our directory structure looks like this:

```
.
├── README.md
├── ansible.cfg
├── inventories
│   ├── bianca-blog
│   │   ├── dev
│   │   │   └── hosts
│   │   └── stage
│   │       └── no_hosts_file
│   └── bianca-sideproject
│       ├── dev
│       └── production
├── playbooks
│   ├── bianca-blog
│   │   └── site.yml
│   ├── bianca-sideproject
│   │   └── bianca-sideproject.yml
│   ├── bianca-sideproject.yml
│   └── site.yml
└── roles

```

In this case, we have multiple services (`bianca-blog`, and `bianca-sideproject`) and multiple playbooks that correspond to these services.

This is what the `inventories/bianca-blog/dev/hosts` file looks like:
```
[app]
example.app.com
example.app.dockerized.com

[db]
example.db.com
example.db.dockerized.com

[docker]
example.dockerservice.com
example.app.dockerized.com
example.db.dockerized.com
```


To run a playbook using the `hosts` inventory file in the `dev` servers (which uses `dev/hosts`), use:

```
./ap.sh bianca-blog.dev site.yml
```

```
[EXEC]: ansible-playbook -i $PROJECT_ROOT/inventories/bianca-blog/dev/hosts $PROJECT_ROOT/playbooks/bianca-blog/site.yml
```
