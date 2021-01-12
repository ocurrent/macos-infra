MacOS Infrastructure
--------------------

Ansible playbook for deploying infrastructure for MacOS for OCurrent workers and the like. Large portions are based on the excellent [Mac Dev Playbook](https://github.com/geerlingguy/mac-dev-playbook).

For some core setup things, we use `ansible-galaxy` -- checkout *requirements.yml* for that list.

## Setup

If you use the virtual environment then you can install the test dependencies with `pip install -r ./tests/requirements.txt`. After that some good things to test are: 

```sh
$ ./env/bin/yamllint .github roles main.yml tests ./requirements.yml
```

And also: 

```sh
$ ./env/bin/ansible-playbook main.yml --syntax-check
```