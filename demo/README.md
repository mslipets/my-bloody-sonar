# Demo

Shows how to run sonar and configure it in dynamic and incremental manner.

Running [docker-compose.yml](docker-compose.yml) that contains the following services:
* postgres - the postgres database for sonar backend.
* ldap - a simple openldap server that is prepopluated on startup using [custom.ldif](assets/ldap/bootstrap/custom.ldif)
* sonar - My Bloody Sonar that watches changes from config.yml


## Prerequisites
* docker for mac/windows/linux
* docker-compose

> If you have a corporate proxy, please fill the proxy information inside [.env](.env) file.

### Starting up a clean sonar

```shell
docker-compose up -d; sleep 60
open http://localhost:9000

```

after startup sonar gets preconfigured with new custom admin user with a name and password<br>
provided by `SONAR_ADMIN_USERNAME`,`SONAR_ADMIN_PASSWORD` environment variables<br>
and disabled default builtin Administrator user (to prevent risk of insecure defaults usage).


### Adding simple general config
We will add `serverBaseURL`, `logoUrl` `aboutText`

```shell
cat config-templates/01-general-config.yml >> config.yml; sleep 10
open http://localhost:9000/admin/settings
```

### Adding LDAP Config
We will add an LDAP Authentication/Authorization

```shell
cat config-templates/02-ldap.yml >> config.yml; sleep 10
open http://localhost:8080
```

|username|password|groups|
|---|---|---|
|bob.dylan|password|developers, team-leaders
|james.dean|password|developers|
|sonar.ldap.admin|password|jenkins-admins


### Enable guest read access
We will enable guests to see dashboard and projects scans results.

```shell
cat config-templates/03-force-auth-off.yml >> config.yml; sleep 10
open http://localhost:8080
```

## Cleaning up
```shell
# Terminate
docker-compose down --remove-orphans --volumes
```
