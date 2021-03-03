ARG FROM_TAG=latest

FROM sonarqube:${FROM_TAG}

ARG GOSU_VERSION=1.12
ARG ENVCONSUL_VERSION=0.10.0
ARG AWS_ENV_VERSION="v1.0.2"
ARG AWS_ENV_CHECKSUM="b8b6a8bd5bd2260fbcea1c888a9711fc"
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
          apt-get install -y --no-install-recommends curl python3 python3-setuptools python3-pip jq && \
          rm -rf /var/lib/apt/lists/* \
          ; \
     fi

RUN  pip3 install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir wheel \
  && pip install --no-cache-dir awscli PyYAML six requests botocore boto3

RUN curl $CURL_OPTIONS https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.tgz | tar -C /usr/bin -xvzf - && \
    chmod +x /usr/bin/envconsul

RUN curl $CURL_OPTIONS -o /usr/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 && \
     chmod +x /usr/bin/gosu

#TODO: to lookup latest aws-env with md5sum, probably in makefile.
RUN curl $CURL_OPTIONS -o /usr/local/bin/aws-env https://github.com/telia-oss/aws-env/releases/download/${AWS_ENV_VERSION}/aws-env-linux-amd64 && \
      echo "$AWS_ENV_CHECKSUM  /usr/local/bin/aws-env" | md5sum -c && \
      chmod +x /usr/local/bin/aws-env

ENV CONFIG_FILE_LOCATION=/dev/shm/sonar-config.yml
ENV TOKEN_FILE_LOCATION=/dev/shm/.api-token
ENV CONFIG_CACHE_DIR=/dev/shm/.sonar-config-cache

RUN chown -R sonarqube:sonarqube "$SONARQUBE_HOME"
COPY --chown=sonarqube:sonarqube bin/* $SONARQUBE_HOME/bin/

# We will change the user to sonarqube using gosu
ENV PATH="${SONARQUBE_HOME}/bin":$PATH
WORKDIR ${SONARQUBE_HOME}
EXPOSE 9000
ENTRYPOINT ["entrypoint.sh"]
CMD []
