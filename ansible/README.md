# Using Ansible to configure OpenBoxes hosts

## What is this?

The `playbooks` directory contains Ansible playbooks for the following tasks:

- `upgrade_packages.yml` runs a series of apt commands to bring a host running Ubuntu 22.04 LTS up to date.
- `install_requirements.yml` installs and configures the software and services OpenBoxes requires.
- `enable_bamboo_deploys.yml` configures a host so that Bamboo can deploy OpenBoxes to it (optional).
- `enable_pih_user_access.yml` configures a host to allow PIH developer access (optional).
- `install_monitoring.yml` installs New Relic monitoring on a host (optional).
- `install_zerotier.yml` installs ZeroTier VPN software on a host (optional).

The `dba` directory contains Ansible playbooks for the following database-related tasks:

- `archive_db.yml` archives the database from a running OpenBoxes instance.
- `reset_db.yml` erases and resets the named database entirely. Use with care!
- `restore_db.yml` restores (or replaces) a previously-archived database file.

## Configuring a host to send Ansible commands

1. [Install Ansible.](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).
2. [Install `ansible-lint`.](https://ansible-lint.readthedocs.io)
   (optional, if developing playbooks).
3. Install [New Relic's Ansible plug-in](https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/config-management-tools/configure-infrastructure-agent-using-ansible/)
   (optional, if you want New Relic support) by running
   `ansible-galaxy install newrelic.newrelic-infra` in a terminal.
4. Ask colleagues for appropriate SSH key pair(s) for the host(s) you need to
   access, and place them in `~/.ssh/`.
5. The repository itself contains obscured secrets (mostly API keys). Ask a
   colleague for the secret UUID and put it in `$WORKSPACE/ansible/secrets/key`.

## Configuring a target to receive Ansible commands

1. Place the public key from step #4, above, in `/root/.ssh/authorized_keys`.
2. Edit `/etc/ssh/sshd_config` to permit root access over SSH, if it isn't already.
   On Azure systems, you may need to edit the `AllowUsers` and `PermitRootLogin` settings.
3. If `ssh root@your.host` doesn't work, neither will Ansible. You can debug the
   connection using the `-v` flag.

## Example 1: Use playbooks to bring up a dev host

```
# Apply latest Ubuntu 22.04 updates
$ ansible-playbook -i inventories/pih_rimu.yml playbooks/upgrade_packages.yml -l obdev1

# Install required dependencies
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/install_requirements.yml -l obdev1

# Install optional capabilities
$ ansible-playbook -i inventories/pih_rimu.yml playbooks/apply_security_rules.yml -l obdev1
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/enable_bamboo_deploys.yml -l obdev1
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/enable_pih_user_access.yml -l obdev1
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/install_monitoring.yml -l obdev1
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/install_zerotier.yml -l obdev1
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/install_bamboo_remote_agent.yml -l obdev1

# Extract database data from the production instance in Azure
$ ansible-playbook -e @secrets/vault_azure -i inventories/pih_azure.yml dba/archive_db.yml -l obnav

# Upload that database data to your dev machine
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l obdev1

# Now you can deploy openboxes via tomcat manager, or bamboo (if so configured)
```

## Example 2: Use playbooks to restore a PIH host to "factory settings"

```
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/pih_main.yml -l obdev1

# Create a new, empty database (use with care!!)
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/reset_db.yml -l obdev1
```

## Example 3: Use playbooks to copy the production database to the staging instance

```
# Extract database data from the production instance in Azure
$ ansible-playbook -e @secrets/vault_azure -i inventories/pih_azure.yml dba/archive_db.yml -l obnav

#
# Upload that database data to the stg instance.
#
# Note the build target in this case is a group, not a host. This playbook not
# only needs to replace the database on dbstg, but also restart tomcat on obstg.
#
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l stg -e 'force=true'
```

## Example 4: Use playbooks to copy the production database to your local machine

```
$ ansible-playbook -e @secrets/vault_azure -i inventories/pih_azure.yml dba/archive_db.yml -l obnav
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l localhost -e 'force=true'
```

## Example 5: Use sftp, cp, and playbooks to restore a backup of the production database

```
$ sftp openboxes@host-90420072.bakop.com
# backups are timestamped, you can find them via ls and pull them down via get
> ls /home/openboxes/dbprd.pih-emr.org
...
> get /home/openboxes/dbprd.pih-emr.org/2023-05-18T16-33-47Z/openboxes.tgz
# copy the backup to where the restore playbook expects it
$ cp openboxes.tgz build/archive_db/dbprd/
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l prd -e 'force=true'
```

## Example 6: Completely tear down and re-create a host (involved)

The following instructions assume you're using RIMU. Other hosting providers will
have different ways of destroying a VM.

1. Find the host in [RIMU's control panel](https://rimuhosting.com/cp/serverlist.jsp?user_oid=73127431).
2. Click Install/reinstall.
3. Select “Ubuntu 22.04 64-bit (Jammy Jellyfish), 5 yr long term support (LTS)”.
4. Type something informative in the “Reason for install” box.
5. Press the “Shutdown and Reinstall” button at the bottom.

When the host comes back up it will have different `ssh` keys! This means Ansible
won't want to connect to it, and neither will our Bamboo agents.

1. Use `ssh` to connect to the host. You should get a warning about a man-in-the-middle
   attack. You'll need to remove the stale entry from your `known_hosts` file.
2. Once you can `ssh` to the newly-provisioned host, look at the new `known_hosts` entry.
3. Copy the entry you found in 2 to `secrets/known_hosts` in this repository.
4. Run the following command to allow bamboo workers to deploy to the host again:
   ```
   ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/install_bamboo_remote_agent.yml`
   ```
5. Now you can reinstall all the required dependencies with Ansible:
   ```
   ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/pih_main.yml -l $HOST`
   ```

## Exceptions to the rule

Legacy hosts aren't configured as consistently as those in RIMU. A few things to
bear in mind.

1. `obdev` has a different password for `openboxes` than does any other host.
   To use any of the playbooks in `dba/*` on `obdev`, you will need to decrypt
   `secrets/vault_azure` and read the comments.
2. You may get errors like `mysqldump: Couldn't execute 'FLUSH TABLES': Access
   denied; you need (at least one of) the RELOAD privilege(s) for this operation
   (1227)"` on `obnavtest1` and `obnavtest2` when running the `dba/*` playbooks.
   If so, you'll want to specify `-e db_username=root` on the command line.
3. In general, your mileage may vary on these hosts.

## Editing or adding secrets

1. To decrypt secrets: `ansible-vault decrypt secrets/vault_*`
2. Edit the vault as you see fit
3. To encrypt secrets: `ansible-vault encrypt secrets/vault_*`
4. _Don't even think of committing between steps 1 and 3!!_

## Code style

- Wrap octal numbers in single-quotes to prevent YML surprises
- Bonus points for running `ansible-lint */*.yml` before making a PR

## Philosophical musings about how Ansible works

An Ansible playbook is a collection of tasks that sort of specify what you want
to do but _really_ specify what you want to _have done_: ideally, they're at
least somewhat more declarative than imperative. Consider the `ansible.builtin.apt`
task, which takes a `state: latest` parameter. When it completes, all dependencies
in the `pkg:` block will be installed and brought up to date. If they already are,
then the task won't run.

For an apt task, that's fairly straightforward. Things get a little trickier in
tasks that add, remove, or change lines. If you can write an idempotent task that
does the same thing if you run it one time or two times, you'll be in good shape.

## What goes where?

### Variables

- Are they the sort of secret you wouldn't put under source control?
  - `ansible/secrets/vault_*`
- Do they, or could they, vary between hosts?
  - `inventories/*.yml`, see existing `vars` blocks for inspiration
- Are they consistently applied, but only for one playbook?
  - `vars` block, either at the top of a play for globals or within a block for locals

### Config files

- Many config files are generated from the `templates/` directory. You can search
  for the template's filename within playbook yml files to see where the template
  is copied.
- Other config files are only slightly modified from the defaults present on a
  fresh install. These are usually edited with `lineinfile` and `blockinfile`
  tasks

You can get almost every file we edit by running the following command:

`egrep '(path|dest):' playbooks/*`

### Logs

Almost everything winds up somewhere in `/var/log`, as it should.

- Bamboo remote agent `/var/log/bamboo-remote-agent/*`
- firewall `/var/log/ufw.log`
- MariaDB `/var/log/mysql/*`
- New Relic `/var/log/newrelic-infra/*`
- Nginx `/var/log/nginx/*`
- Tomcat 7 `/var/log/tomcat7/*`
- Tomcat 8.5 `/var/log/tomcat85/*`

Exceptions:
- Grails still may dump some stack traces to Tomcat's working directory, `/var/lib/tomcat*/stacktrace.log`.
