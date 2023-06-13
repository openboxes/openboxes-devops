# Using Ansible to configure OpenBoxes hosts

## What is this?

The `playbooks` directory contains Ansible playbooks for the following tasks:

- `apt.yml` brings a host running Ubuntu 22.04 LTS up to date.
- `swap.yml` is an optional playbook that enables swap on a host.
- `database.yml` installs a database server (MariaDB or Oracle MySQL).
- `webserver.yml` installs Java and Tomcat.
- `reverseproxy.yml` configures certificates via Certbot, then makes them
  available to Nginx and the database server.
- `users.yml` sets up user accounts in the O/S, database and Tomcat manager.
- `security.yml` installs antivirus software and a firewall.
- `deployment.yml` prepares a host for deployments from a CI server like Bamboo.
- `monitoring.yml` installs New Relic and Sentry monitoring on a host
  (optional).
- `vpn.yml` installs ZeroTier VPN software on a host (optional).
- `buildagent.yml` makes a host available for remote Bamboo builds (optional).
- `backup.yml` configures a host to push nightly database backups to an offsite
  server.
- `configure.yml` installs configuration files.

The `dba` directory contains Ansible playbooks for the following
database-related tasks:

- `archive_db.yml` archives the database from a running OpenBoxes instance.
- `reset_db.yml` erases and resets the named database entirely. Use with care!
- `restore_db.yml` restores (or replaces) a previously-archived database file.

## Configuring a host to send Ansible commands

1. [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).
2. Install additional Ansible dependencies by running
   ```
   $ ansible-galaxy collection install ansible.posix community.general
   ```
   in a terminal.
3. [Install `ansible-lint`.](https://ansible-lint.readthedocs.io)
   (optional, but highly recommended if developing playbooks).
4. Install
   [New Relic’s Ansible plug-in](https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/config-management-tools/configure-infrastructure-agent-using-ansible/)
   (optional, if you want New Relic support) by running
   ```
   $ ansible-galaxy install newrelic.newrelic-infra
   ```
   in a terminal.
5. Ask colleagues for appropriate SSH key pair(s) for the host(s) you need to
   access, and place them in `~/.ssh/`.
6. The repository itself contains obscured secrets (mostly API keys). Ask a
   colleague for the secret UUID and put it in `$WORKSPACE/ansible/secrets/key`.

## Configuring a target to receive Ansible commands

1. Place the public key from step #5, above, in `/root/.ssh/authorized_keys`.
2. Edit `/etc/ssh/sshd_config` to permit root access over SSH, if it isn’t
   already. (On Azure systems, you may need to edit the `AllowUsers` and
   `PermitRootLogin` settings.
3. If `ssh root@your.host` doesn’t work, neither will Ansible. You can debug the
   connection using the `-v` flag.

## Example 1: Use playbooks to bring up a host

```
# Install everything we need
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/main.yml -l $TARGET

# Extract database data from the production instance
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/archive_db.yml -l prd

# Upload that database data to the new machine
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l $TARGET

# Note the playbook's warning that it cannot verify the restore because Openboxes is not installed

# Now you can deploy Openboxes itself via Tomcat manager, or Bamboo (if so configured)
```

## Example 2: Use playbooks to restore a host to “factory settings”

```
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/main.yml -l $TARGET

# Create a new, empty database (use with care!!)
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/reset_db.yml -l $TARGET
```

## Example 3: Use playbooks to quickly refresh (nearly) all configuration on a host

```
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/configure.yml -l $TARGET
```

## Example 4: Use playbooks to copy the production database to the staging instance

```
# Extract database data from the production instance
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/archive_db.yml -l prd

#
# Upload that database data to the stg instance.
#
# Note the build target in this case is a group, not a host. This playbook needs
# to both replace the database on dbstg, and also restart tomcat on obnavstage.
#
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l stg -e 'force=true'
```

## Example 5: Use playbooks to copy the production database to your local machine

```
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/archive_db.yml -l prd
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l localhost -e 'force=true'
```

## Example 6: Use sftp, cp, and playbooks to restore a historical backup of the production database

```
# Back up current database state for later debugging
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/archive_db.yml -l prd
$ mv build/archive_db/dbprd/openboxes.tgz build/archive_db/dbprd/openboxes-pre-restoration.tgz

# Now connect to the backup host and browse its backups
$ sftp openboxes@host-90420072.bakop.com (`backup_target` in the inventory file)
# Backups are timestamped, you can find them via ls and pull them down via get
> ls /home/openboxes/dbprd.pih-emr.org
...
> get /home/openboxes/dbprd.pih-emr.org/2023-05-18T16-33-47Z/openboxes.tgz

# Move the backup to where the restore playbook expects it
$ mv openboxes.tgz build/archive_db/dbprd/

# Upload the backup to the production database -- use with care!
$ ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml dba/restore_db.yml -l prd -e 'force=true'
```

## Example 7: Completely tear down and re-create a host (involved)

The following instructions assume you’re using RIMU. Other hosting providers
will offer different ways of destroying a VM.

1. Find the host in [RIMU’s control panel](https://rimuhosting.com/cp/serverlist.jsp?user_oid=73127431).
2. Click Install/reinstall.
3. Select “Ubuntu 22.04 64-bit (Jammy Jellyfish), 5 yr long term support (LTS)”.
4. Type something informative in the “Reason for install” box.
5. Press the “Shutdown and Reinstall” button at the bottom.

When the host comes back up it will have different `ssh` keys! This means
Ansible won’t want to connect to it, and neither will our Bamboo agents.

1. Use `ssh` to connect to the host. You should get a warning about a
   man-in-the-middle attack. You’ll need to remove the stale entry from your
   `known_hosts` file.
2. Once you can `ssh` to the newly-provisioned host, look at the new
   `known_hosts` entry.
3. Copy the entry you found in 2 to `secrets/known_hosts` in this repository.
4. Run the following command to allow bamboo workers to deploy to the host
   again:
   ```
   ansible-playbook -e @secrets/vault_rimu -i inventories/pih_rimu.yml playbooks/buildagent.yml`
   ```
5. Now you can follow Example #1 to install dependencies, copy a database, and
   prepare the host for CI deployment.

## Using these playbooks on older servers (like those in Azure)

Legacy hosts aren’t configured as consistently as those in RIMU. A few things to
bear in mind.

1. `obdev` has a different password for `openboxes` than does any other host.
   To use any of the playbooks in `dba/*` on `obdev`, you will need to decrypt
   `secrets/vault_azure` and read the comments.
2. You may get errors like `mysqldump: Couldn't execute 'FLUSH TABLES': Access
   denied; you need (at least one of) the RELOAD privilege(s) for this operation
   (1227)` on `obnavtest1` and `obnavtest2` when running the `dba/*` playbooks.
   If so, you’ll want to specify `-e db_username=root` on the command line.
3. In general, your mileage may vary on these hosts.

## Editing or adding secrets

1. To decrypt secrets: `ansible-vault decrypt secrets/vault_*`
2. Edit the vault as you see fit
3. To encrypt secrets: `ansible-vault encrypt secrets/vault_*`
4. _Don’t even think of committing between steps 1 and 3!!_

## Code style

- Wrap octal numbers in single-quotes to prevent YML surprises
- Bonus points for running `ansible-lint */*.yml` before making a PR

## Philosophical musings about how Ansible works

An Ansible playbook is a collection of tasks that sort of specify what you want
to do but _really_ specify what you want to _have done_: ideally, they’re at
least somewhat more declarative than imperative. Consider the
`ansible.builtin.apt` task, which takes a `state: latest` parameter. When it
completes, all dependencies in the `pkg:` block will be installed and brought up
to date. If they already are, then the task won’t run.

For an apt task, that’s fairly straightforward. Things get a little trickier in
tasks that add, remove, or change lines. If you can write an idempotent task
that does the same thing if you run it one time or two times, you’ll be in good
shape.

## What goes where?

### Variables

- Are they the sort of secret you wouldn’t put under source control?
  - `ansible/secrets/vault_*`
- Do they, or could they, vary between hosts?
  - `inventories/*.yml`, see existing `vars` blocks for inspiration
- Are they consistently applied, but only for one playbook?
  - `vars` block, either at the top of a play for globals or within a block for
    locals

### Config files

- Many config files are generated from the `templates/` directory. You can
  search for the template’s filename within playbook yml files to see where the
  template is copied.
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
- Grails still may dump some stack traces to Tomcat’s working directory,
  `/var/lib/tomcat*/stacktrace.log`.

## I don’t like the tools and dependencies you chose

We did our best to choose reliable, easy-to-configure and well-supported
dependencies in this repository. We highly recommend using these playbooks as
presented, because they are what we use for developing and deploying the most
heavily used Openboxes instances. We cannot support installations using
different tools than what we provide in this repository.

That being said, we don’t want to get in the way of any practical (or even
philosophical) desires to run Openboxes in a different environment. That’s
totally fine, and if you add support to a new tool or dependency we’d love to
hear about it! However, your mileage may vary, and, again, we cannot offer
support beyond what this repository contains.

### I don’t like Ubuntu

These scripts should work pretty well on any recent Debian-based Linux distro,
as the lowest-level parts of these playbooks interact with `apt` and `systemd`.
It shouldn’t be tremendously difficult to go further afield than that, although
you’ll need to make changes to almost every playbook in the repository. We don’t
do anything too clever in here, and there’s no reason Openboxes shouldn’t run on
almost any POSIX-compliant O/S.

### I don’t like MariaDB

You can tell these scripts to use Oracle MySQL 8.0.x instead by setting
`inventory.db_type: mysql` in your inventory file. Note that a clean Ubuntu 22
installation may contain MariaDB data in `/var/lib/mysql/` and Oracle MySQL may
refuse to start up at first. If so, check `/etc/mysql/FROZEN` and follow its
instructions.

Using anything other than MySQL-based database servers is a heavier lift, as
Openboxes’ migration scripts contain MySQL-specific code. Good luck!

### I don’t like Nginx

You’ll want to edit `reverseproxy.yml` to install Apache or Caddy or whatever
you’d rather use. Let us know how it goes!

### I don’t like Tomcat

If you’d rather use Jetty, you’ll want to edit `webserver.yml` and possibly make
a custom OpenBoxes build with the correct Spring Boot starters for whichever
webserver you like more.

### I don’t like Bamboo

Neither do we! Update `deployment.yml` as required to enable your CI tool of
choice to access the host, and, optionally, `buildagent.yml` to create a
suitable development environment on your CI workers.

### I don’t like New Relic and Sentry

One option is simply to not run `monitoring.yml`. If you want to send telemetry
to a different provider, you’ll want to edit that file and (most likely) create
a custom Openboxes build with the appropriate hooks for whichever monitoring
tool you prefer.

### I want to backup somewhere else

Update `backup.yml` to connect elsewhere. Any site that accepts scp and sftp
connections should be pretty easy to work with.
