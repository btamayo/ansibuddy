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


To run a playbook on the `hosts` inventory file in my `dev` servers, I can run:

```
./ap.sh bianca-blog.dev site.yml
```

```
[EXEC]: ansible-playbook -i /Users/btamayo/Development/ansibuddy/samples/example-1/inventories/bianca-blog/dev/hosts /Users/btamayo/Development/ansibuddy/samples/example-1/playbooks/bianca-blog/site.yml
```