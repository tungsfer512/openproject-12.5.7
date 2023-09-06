---
sidebar_navigation:
  title: Monitoring & Logs
  priority: 6
---

# Monitoring your OpenProject installation

## Show logs

In a package-based installation, the `openproject` command line tool can be
used to see the log information. The most typically use case is to show/follow
all current log entries. This can be accomplished using the the `–tail` flag.
See example below:

```bash
sudo openproject logs --tail
```

You can abort this using Ctrl + C.

Note:

* On distributions that are based on systemd, all the logs are sent to journald, so you can also display them via `journalctl`.
* On older distributions that use either sysvinit or upstart, all the logs are stored in `/var/log/openproject/`.
* If you need to share the logs you can save them in a file using `tee` like this: `sudo openproject logs --tail | tee openproject.log`

In a docker-based installation, all logs are redirected to STDOUT so you can use the normal docker tools to manage your logs.

For instance for the Compose-based installation:

```bash
docker-compose logs -f --tail 1000
```

Or the all-in-one docker installation:

```bash
docker logs -f --tail 1000 openproject
```

### Raising the log level

OpenProject can log at different service levels, the default being `info`. You can set the [environment variable](../../configuration/environment/#environment-variables) `OPENPROJECT_LOG__LEVEL` to any of the following values:

- debug, info, warn, error

For example, to set this in the packaged installation, use the following command:

```bash
openproject config:set OPENPROJECT_LOG__LEVEL="debug"
service openproject restart
```

For Docker-based installations, add the ENV variable to your env file and restart the containers.
