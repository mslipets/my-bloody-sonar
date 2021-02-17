# My Bloody Sonar - An opinionated SonarQube Docker Image
Self Configured SonarQube Docker image based on Official SonarSource Images
<br>
(heavily influenced by [My Bloody SonarQube](https://github.com/mslipets/my-bloody-sonar) and [telia-oss/terraform-aws-sonarqube](https://github.com/telia-oss/terraform-aws-sonarqube))

## What's in the Box?
*My Bloody Sonar* is a re-distribution of the [Official Docker image for SonarQube](https://hub.docker.com/_/sonarqube) bundled with most popular plugins and
ability to configure most aspects of SonarQube from a **simple** and **single source of truth** represented as YAML.

The image can get the configuration from several data sources such as: File, S3, Environment Variable, HTTP, Kubernetes ConfigMap and Kubernetes Secret.

//TODO: The image supports "Watching" configuration changes and applying them immediately without restarting SonarQube.

## Features
* Configuration Coverage:
//TODO:  * Authorization


## Why Use the term "Bloody"?
As [original quote](https://github.com/mslipets/my-bloody-sonar#why-use-the-term-bloody) says:<br>
"The term "My Bloody SonarQube" came from the fact that I tried to put all my "battle" experience, (i.e. blood, sweat and tears) within the image.
I just thought it is a "catchy" name for this kind of a repository." (c) [Ohad David](https://github.com/odavid)
<br>
I thought these epithets is also pretty suitable for this custom SonarQube image.

## Demo

> Note: for proper ElasticSearch service startup in sonar container `vm.max_map_count=262144` <br>
> should be adjusted on host:<br>
`sudo sysctl -w vm.max_map_count=262144`


//TODO

## Some Usage Examples
//TODO


## Releases
Docker Images are pushed to [Docker Hub](https://hub.docker.com/r/mslipets/my-bloody-sonar/)

Each release is a git tag v$VERSION-$INCREMENT where:

* VERSION is the SonarQube version
* INCREMENT is a number representing that representing the release contents (i.e additional configuration options, bugs in configuration, plugins, etc...)

For each git tag, there following tags will be created:
* $VERSION-$INCREMENT - one to one relationship with git tag
* $VERSION - latest release for that community version
* lts - represents the latest release


Each master commit, will be tagged as latest

```bash
# get the LTS release (openjdk:11-jre-slim) alternative tags: 7.9.5-community, 7.9-community, lts
docker pull mslipets/my-bloody-sonar:lts
# get the latest community version (alpine) alternative tags: 8.6.1-community, 8.6-community, 8-community, community, latest
docker pull mslipets/my-bloody-sonar:latest #
# get the latest developer version (alpine) alternative tags: 8.6.1-developer, 8.6-developer, 8-developer, developer
docker pull mslipets/my-bloody-sonar:developer
# get the latest enterprise version (alpine) alternative tags: 8.6.1-enterprise, 8.6-enterprise, 8-enterprise, enterprise
docker pull mslipets/my-bloody-sonar:enterprise
# get a concrete 8.6.1-developer release
docker pull mslipets/my-bloody-sonar:8.6.1-developer

```

## Environment Variables
The following Environment variables are supported

Besides all [Environment variables](https://docs.sonarqube.org/latest/setup/environment-variables/) supported by [Official Docker image for SonarQube](https://hub.docker.com/_/sonarqube)


* `SONAR_ADMIN_USERNAME` - (***mandatory***) Represents the name of the admin user. If LDAP/SAML is your choice of authentication, then this should be a valid LDAP user id. If using own Database, then you also need to pass the password of this user within the [configuration](#configuration-reference).

> Bare minimum to be set is:<br>
`SONAR_ADMIN_USERNAME`<br>
`SONAR_ADMIN_PASSWORD`<br>
`SONAR_JDBC_USERNAME`<br>
`SONAR_JDBC_PASSWORD`<br>
`SONAR_JDBC_URL`<br>
`SONAR_BASE_URL`<br>

* `SONAR_ADMIN_ADDRESS` - Define the SonarQube admin email address

* __JAVA_OPTS\_*__ - All JAVA_OPTS_ variables will be appended to the JAVA_OPTS during startup. Use them to control options (system properties) or memory/gc options. I am using few of them by default to tweak some known issues:

* `SONAR_ENV_CONFIG_YAML` - The [configuration](#configuration-reference) as yaml. When this variable is set, the contents of this variable can be fetched from Consul and also be watched so SonarQube can update its configuration everytime this variable is being changed. Since the contents of this variable contains secrets, it is wise to store and pass it from Consul/S3 bucket. In any case, before SonarQube starts, this variable is being unset, so it won't appear in SonarQube 'System Information' page (As I said, blood...)

* `SONAR_ENV_CONFIG_YML_URL` - A comma separated URLs that will be used to fetch the configuration and updated SonarQube everytime the change. This is an alternative to __SONAR_ENV_CONFIG_YAML__ setup.
  Supported URLs:
  * `s3://<s3path>` - s3 path
  * `file://<filepath>` - a file path (should be mapped as volume) - can be a file, folder or glob expression (e.g. `file:///dir/filename` or `file:///dir` or `file:///dir/*.yml`)
  * `http[s]://<path>` - an http endpoint

> Note: If multiple URLs are passed, or the file url contains a dir name or a glob expression, all yaml files are being deep merged top to bottom. This behavior enables to separate the configuration into different files or override default configuration.


* `SONAR_ENV_CONFIG_YML_URL_DISABLE_WATCH` - If equals to 'true', then the configuration file will be fetched only at startup, but won't be watched. Default 'false'

* `SONAR_ENV_CONFIG_YML_URL_POLLING` - polling interval in seconds to check if file changed in s3. Default (30)

//TODO: * `SONAR_ENV_PLUGINS` - Ability to define comma separated list of additional plugins to install before starting up. See [plugin-version-format](https://github.com/SonarQubeci/docker#plugin-version-format).
> This is option is not recommended, but sometimes it is useful to run the container without creating an inherited image.


## Configuration Reference
The configuration is divided into main configuration sections. Each section is responsible for a specific aspect of SonarQube configuration.








## License

Licensed under either of

* Apache License, Version 2.0
  ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
* MIT license
  ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.

## Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be
dual licensed as above, without any additional terms or conditions.
