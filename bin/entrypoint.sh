#! /bin/bash -e

if [ -z "$AWS_REGION" ] && [ -z "$AWS_DEFAULT_REGION" ]; then
    export AWS_REGION="eu-west-1"
fi

export ssm_env="/usr/local/bin/aws-env exec"

if [[ $# -lt 1 ]] || [[ "$1" == "-"* ]]; then
    JAVA_OPTS_VARIABLES=$(compgen -v | while read line; do echo "$line" | grep JAVA_OPTS_;done) || true
    for key in $JAVA_OPTS_VARIABLES; do
        echo "adding: ${key} to JAVA_OPTS"
        export JAVA_OPTS="$JAVA_OPTS ${!key}"
    done

    if [ -n "${SONAR_ENV_CONFIG_YAML}" ]; then
        echo -n "$SONAR_ENV_CONFIG_YAML" > "$CONFIG_FILE_LOCATION"
        unset SONAR_ENV_CONFIG_YAML
    elif [ -n "${SONAR_ENV_CONFIG_YML_URL}" ]; then
          echo "Fetching config from URL: ${SONAR_ENV_CONFIG_YML_URL}"
          ssm_env watch-config.sh \
             --debug \
             --cache-dir "$CONFIG_CACHE_DIR" \
             --url "${SONAR_ENV_CONFIG_YML_URL}" \
            --skip-watch

        if [ "$SONAR_ENV_CONFIG_YML_URL_DISABLE_WATCH" != 'true' ]; then
            echo "Watching config from URL: ${SONAR_ENV_CONFIG_YML_URL} in the background"
            ssm_env nohup watch-config.sh \
                --cache-dir "$CONFIG_CACHE_DIR" \
                --url "${SONAR_ENV_CONFIG_YML_URL}" \
                --polling-interval "${SONAR_ENV_CONFIG_YML_URL_POLLING:-30}" &
        fi
    fi

    if [ -n "$SONAR_ENV_PLUGINS" ]; then
        echo "Installing additional plugins $SONAR_ENV_PLUGINS"
        install-plugins.sh $(echo "$SONAR_ENV_PLUGINS" | tr ',' ' ')
        chown chown -R sonarqube:sonarqube "$SONARQUBE_HOME/extensions/plugins"
        echo "Installing additional plugins. Done..."
    fi

    # This is important if you let docker create the host mounted volumes.
    # We need to make sure they will be owned by the sonarqube user
    if [ ! -n "${DISABLE_CHOWN_ON_STARTUP}" ]; then
        echo "Chowning $SONARQUBE_HOME"
        if [ "sonarqube" != "$(stat -c %U "${SONAR_HOME}")" ]; then
            chown -R sonarqube:sonarqube "$SONARQUBE_HOME"
        fi
        echo "Chowning $SONARQUBE_HOME. Done"
        unset DISABLE_CHOWN_ON_STARTUP
    else
        echo "Chowning $SONARQUBE_HOME disabled"
    fi

    # This changes the actual command to run the original sonarqube entrypoint
    # using the sonarqube user
    set -- gosu sonarqube ssm_env "bin/start.sh" "$@"
fi

exec "$@"
