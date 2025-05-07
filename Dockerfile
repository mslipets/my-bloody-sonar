# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

ARG FROM_TAG=latest

FROM sonarqube:${FROM_TAG}

ARG GOSU_VERSION=1.17
ARG ENVCONSUL_VERSION=0.13.3
ARG AWS_ENV_VERSION=1.3.0
ARG AWS_ENV_CHECKSUM="62f67b83574d8417e792eb32bd5d989e5fa826d190d57c8d2309ba7047693646"
## Using -k for the time being
ARG CURL_OPTIONS=-sSfLk

# Using root to install and run entrypoint.
# We will change the user to sonarqube using gosu
USER root

# Install plugins
#TODO: parse plugins list elswhere and invoke:
#find out if mounted voliume wont override plugins content
# e.g.: RUN curl $CURL_OPTIONS https://binaries.sonarsource.com/Distribution/sonar-auth-github-plugin/sonar-auth-github-plugin-1.5.0.870.jar > /opt/sonarqube/extensions/plugins/sonar-auth-github-plugin-1.5.0.870.jar && \
  #      echo 59d98c94277e5faa8377ba521e440eba  ${SONARQUBE_HOME}/extensions/plugins/sonar-auth-github-plugin-1.5.0.870.jar | md5sum -c
## Install plugins
#COPY plugins.txt "$SONARQUBE_HOME/extensions/plugins/"

RUN \
     # alpine - Install pip and shadow for usermod
     if [ -f /etc/alpine-release ] ; then \
          apk add --no-cache curl shadow python3 py3-setuptools py3-pip jq \
          ; \
     # debian - Install pip
     elif [ -f /etc/debian_version ] ; then \
          apt-get update -y && \
          apt-get install -y --no-install-recommends \
                  curl \
                  jq \
                  python3 \
                  python3-boto3 \
                  python3-botocore \
                  python3-pip \
                  python3-requests \
                  python3-setuptools \
                  python3-six \
                  python3-wheel \
                  python3-yaml \
                  unzip && \
          rm -rf /var/lib/apt/lists/* \
          ; \
     fi

RUN curl $CURL_OPTIONS -o /tmp/envconsul.zip \
    https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip &&\
    unzip /tmp/envconsul.zip -d /usr/bin/ && \
    chmod +x /usr/bin/envconsul

RUN curl $CURL_OPTIONS -o /usr/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 && \
    chmod +x /usr/bin/gosu

RUN curl $CURL_OPTIONS -o /tmp/aws-env-${AWS_ENV_VERSION}-linux-amd64.tar.gz \
          https://github.com/telia-oss/aws-env/releases/download/v${AWS_ENV_VERSION}/aws-env-${AWS_ENV_VERSION}-linux-amd64.tar.gz && \
          echo "$AWS_ENV_CHECKSUM  /tmp/aws-env-1.3.0-linux-amd64.tar.gz" | sha256sum -c && \
          AWS_ENV_TMP_DIR=$(mktemp -d) && tar -C $AWS_ENV_TMP_DIR -xvf /tmp/aws-env-${AWS_ENV_VERSION}-linux-amd64.tar.gz && \
          cp -f $AWS_ENV_TMP_DIR/aws-env /usr/local/bin/ && \
          chmod +x /usr/local/bin/aws-env && \
          rm -fR $AWS_ENV_TMP_DIR

ENV CONFIG_FILE_LOCATION=/dev/shm/sonar-config.yml
ENV TOKEN_FILE_LOCATION=/dev/shm/.api-token
ENV CONFIG_CACHE_DIR=/dev/shm/.sonar-config-cache

RUN chown -R sonarqube "$SONARQUBE_HOME"
COPY --chown=sonarqube bin/* $SONARQUBE_HOME/bin/

# We will change the user to sonarqube using gosu
ENV PATH="${SONARQUBE_HOME}/bin":$PATH
WORKDIR ${SONARQUBE_HOME}
EXPOSE 9000
ENTRYPOINT ["entrypoint.sh"]
CMD []
