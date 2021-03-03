# My Bloody Sonar - An opinionated SonarQube Docker Image
Self Configured SonarQube Docker image based on Official SonarSource Images
<br>
(heavily influenced by [My Bloody SonarQube](https://github.com/mslipets/my-bloody-sonar) and [telia-oss/terraform-aws-sonarqube](https://github.com/telia-oss/terraform-aws-sonarqube))

## What's in the Box?
*My Bloody Sonar* is a re-distribution of the [Official Docker image for SonarQube](https://hub.docker.com/_/sonarqube) bundled with most popular plugins and
ability to configure most aspects of SonarQube from a **simple** and **single source of truth** represented as YAML.

The image can get the configuration from several data sources such as: File, S3, Environment Variable, HTTP, Kubernetes ConfigMap and Kubernetes Secret.

The image supports "Watching" configuration changes and applying them immediately without restarting SonarQube.

## Features
* Configuration Coverage:
  * pretty all settings under sonar.* properties namespace
  * ldap.* properties, although full application of it might require a restart of web engine.<br> 
    (therefore [Environment variables](https://docs.sonarqube.org/latest/setup/environment-variables/#header-4) is recommended)
    



## Why Use the term "Bloody"?
As [original quote](https://github.com/mslipets/my-bloody-sonar#why-use-the-term-bloody) says:<br>
"The term "My Bloody SonarQube" came from the fact that I tried to put all my "battle" experience, (i.e. blood, sweat and tears) within the image.
I just thought it is a "catchy" name for this kind of a repository." (c) [Ohad David](https://github.com/odavid)
<br>
I thought these epithets is also pretty suitable for this custom SonarQube image.

## Demo and Usage Example

A [demo](demo) can be found [here](demo/README.md)


## Releases
Docker Images are pushed to [Docker Hub](https://hub.docker.com/r/mslipets/my-bloody-sonar/)

Each release is a docker tag v$VERSION-$RELEASE where:

* VERSION is the SonarQube app version
* RELEASE is a release  e.g. lts, community, developer, enterprise

For each git tag, there following tags will be created:
* $VERSION-$RELEASE - one to one relationship with git tag
* $RELEASE - `latest` version for that release variant.
* lts - represents the latest lts release


get the [LTS](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated) release (openjdk:11-jre-slim) alternative tags: [lts](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated)
```bash
docker pull mslipets/my-bloody-sonar:lts
```
get the [latest](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated) [community](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated) version (alpine) alternative tags: [8.6.1-community, 8.6-community, 8-community, community, latest](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated)
```bash
docker pull mslipets/my-bloody-sonar:latest
```
get the latest [developer](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated) version (alpine) alternative tags: [8.6.1-developer, developer](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated)
```bash
docker pull mslipets/my-bloody-sonar:developer
```
get the latest [enterprise](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated) version (alpine) alternative tags: [8.6.1-enterprise, enterprise](https://hub.docker.com/_/sonarqube/?tab=tags&page=1&ordering=last_updated)
```bash
docker pull mslipets/my-bloody-sonar:enterprise
```
get a concrete 8.6.1-developer release
```bash
docker pull mslipets/my-bloody-sonar:8.6.1-developer

```

## Environment Variables
The following Environment variables are supported

Besides all [Environment variables](https://docs.sonarqube.org/latest/setup/environment-variables/) supported by [Official Docker image for SonarQube](https://hub.docker.com/_/sonarqube)


* `SONAR_ADMIN_USERNAME` - (***mandatory***) Represents the name of the admin user. If LDAP/SAML is your choice of authentication, then this should be a valid IDP user id. If using own Database, then you also need to pass the password of this user within the [configuration](#configuration-reference).

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

//TODO: * `SONAR_ENV_PLUGINS` - Ability to define comma separated list of additional plugins to install before starting up.
> This is option is not recommended, but sometimes it is useful to run the container without creating an inherited image.


## Configuration Reference
The configuration is provided in yaml format, 
each node with value is corresponds to sonarqube property 
(can be lookup on gui) or in sonar.properties file.

Each key is responsible for a specific aspect of SonarQube configuration.


## [Credits](CREDITS.md)

  - [Ohad David](https://github.com/odavid) for [My Bloody Jenkins](https://github.com/odavid/my-bloody-jenkins)
  - [Telia OSS](https://github.com/telia-oss) for [aws-env](https://github.com/telia-oss/aws-env) and [terraform-aws-sonarqube](https://github.com/telia-oss/terraform-aws-sonarqube)
  - [SonarSource](https://github.com/SonarSource) for original [docker-sonarqube](https://github.com/SonarSource/docker-sonarqube)


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
