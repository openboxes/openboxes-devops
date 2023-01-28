# Using Ansible to configure OpenBoxes hosts

## What is this?

This directory contains Ansible playbooks for the following tasks:

- `apt_upgrade.yml` runs a series of apt commands to bring a host running Ubuntu 22.04 LTS up to date.
- `install_dependencies.yml` installs and configures the software and services OpenBoxes requires.
- `deploy_war.yml` uploads an OpenBoxes warfile to a webserver. (Use bamboo instead, if you can.)
- `archive_db.yml` archives the database from a running OpenBoxes instance.
- `restore_db.yml` restores (or replaces) a previously-archived database file.

## Configuring a host to run Ansible commands

1. [Install Ansible.](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
2. [Install `ansible-lint`.](https://ansible-lint.readthedocs.io) (optional, if developing playbooks)
3. Install [New Relic's Ansible plug-in](https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/config-management-tools/configure-infrastructure-agent-using-ansible/) by running `ansible-galaxy install newrelic.newrelic-infra` in a terminal.
4. Ask colleagues for appropriate SSH key pair(s) for the host(s) you need to access, and place them in `~/.ssh/`
5. The repository itself contains obscured secrets (mostly API keys). Ask a colleague for the secret UUID and put it in `$WORKSPACE/ansible/secret/key`.

## Configuring a host to receive Ansible commands

1. Place the public key from step #4, above, in `/root/.ssh/authorized_keys`.
2. Edit `/etc/ssh/sshd_config` to permit root access over SSH, if it isn't already. On Azure systems, you may need to edit the `AllowUsers` and `PermitRootLogin` settings.
3. If `ssh root@your.host` doesn't work, neither will Ansible. You can debug the connection using the `-v` flag.

## Example 1: Use playbooks to bring up a dev host

```
# Apply latest Ubuntu 22.04 updates to your dev host at RIMU
$ ansible-playbook -i inventories/pih_rimu.yml -l obdev1 apt_upgrade.yml

# Install all OpenBoxes dependencies to your dev host
$ ansible-playbook -e @secrets/vault -i inventories/pih_rimu.yml -l obdev1 install_dependencies.yml

# Extract database data from the production instance in Azure
$ ansible-playbook -e @secrets/vault -i inventories/pih_azure.yml -l prd archive_db.yml

# Upload that database data to your dev machine
$ ansible-playbook -e @secrets/vault -i inventories/pih_rimu.yml -l obdev1 restore_db.yml

# Upload a war file (but you really should use bamboo)
$ ansible-playbook -i inventories/pih_rimu.yml -l obdev1 deploy_war.yml
```

## Example 2: Use playbooks to restore a host to "factory settings"

```
# Apply latest Ubuntu 22.04 updates
$ ansible-playbook -i inventories/pih_rimu.yml -l obdev1 apt_upgrade.yml

# Update all OpenBoxes dependencies
$ ansible-playbook -e @secrets/vault -i inventories/pih_rimu.yml -l obdev1 install_dependencies.yml

# Create a new, empty database (use with care!!)
$ ansible-playbook -e @secrets/vault -i inventories/pih_rimu.yml -l obdev1 reset_db.yml
```

## Editing or adding secrets

1. To decrypt secrets: `ansible-vault decrypt secrets/vault`
2. Edit the vault as you see fit
3. To encrypt secrets: `ansible-vault encrypt secrets/vault`
4. _Don't even think of committing between steps 1 and 3!!_
