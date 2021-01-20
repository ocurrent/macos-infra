MacOS Infrastructure
--------------------

*Status: Experimental*

Ansible playbook for deploying infrastructure for MacOS for OCurrent workers and the like. Large portions are based on the excellent [Mac Dev Playbook](https://github.com/geerlingguy/mac-dev-playbook).

## Setup

If you use the virtual environment then you can install the test dependencies with `pip install yamllint ansible-lint ansible`. After that some good things to test are: 

```sh
$ yamllint .github roles/worker main.yml tests requirements.yml
```

And also: 

```sh
$ ansible-galaxy install -r requirements.yml -p ./roles
$ ansible-playbook main.yml --syntax-check
```

---

### Installed World

This ansible playbook does lots of things. The CI tests that it does the following: 

  - From Homebrew it installs `opam`, `osxfuse` and `pkg-config`. 
  - Via some shell-script incantations it installs `openzfs`. 
  - It installs OCaml system compilers using `opam sysinstall`. 
  - It installs `OCluster` the `Macos` version and `Obuilder-fs` for the FUSE hackery.