#!/bin/bash -e


program=$0
script_dir=$(cd $(dirname "$0"); pwd)

http_hdr="Content-Type: application/x-www-form-urlencoded"

DEFAULT_CREDS="admin:admin"

usage(){
    cat << EOF
Usage: $program <CONFIG_FILE_LOCATION>
Options:
-f, --filename                              - file to be parsed and used as config source.
                                              (same as $program <CONFIG_FILE_LOCATION>)
--debug                                     - Log debug (Default: false)
EOF
    exit 1
}

log(){
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

debug(){
    [[ "$DEBUG" == "YES" ]] && log "$1"
}

wait_for_service(){
  health=$(curl -sL -w "%{http_code}\n" http://localhost:9000/api/system/status -o /dev/null)
  while [[ $health -ne "200" ]]; do
    sleep 300
    health=$(curl -sL -w "%{http_code}\\n" http://localhost:9000/api/system/status -o /dev/null)
  done
}

get_auth(){
  token_file="$TOKEN_FILE_LOCATION"
  AUTH_ARG=""
  if [ -f "${token_file}" ]; then
    AUTH_ARG="$(cat "${token_file}"):"
  else
    AUTH_ARG="${SONAR_ADMIN_USERNAME}:${SONAR_ADMIN_PASSWORD}"
  fi
}

set_auth_token(){
  #TODO: implement
  log "#TODO: implement"
}


is_admin_unsecured(){
  response=$(curl -sL -w "%{http_code}\n" -u "${DEFAULT_CREDS}" -H "${http_hdr}" http://localhost:9000/api/user_tokens/search -o /dev/null)
  debug response
  if [[ response == "200" ]] ; then
    echo "true"
  else
    echo "false"
  fi
}

update_init_admin_creds(){
  if [[ is_admin_unsecured == "true" ]] ; then
    curl -u admin:admin -H "${http_hdr}" -X POST -d "login=${SONAR_ADMIN_USERNAME}&name=Admin&password=${SONAR_ADMIN_PASSWORD}&password_confirmation=${SONAR_ADMIN_PASSWORD}" http://localhost:9000/api/users/create &&
    curl -u admin:admin -H "${http_hdr}" -X POST -d "name=sonar-administrators&login=${SONAR_ADMIN_USERNAME}" http://localhost:9000/api/user_groups/add_user &&
    curl -u "${SONAR_ADMIN_USERNAME}":"${SONAR_ADMIN_PASSWORD}" -H "${http_hdr}" -X POST -d "login=admin" http://localhost:9000/api/users/deactivate
    set_auth_token
  fi
}

update_config(){
  get_auth
  local settings_url="http://localhost:9000/api/settings/set"
  config_map=$("${script_dir}/parseconfig.py" --source "${FILENAME}")

  for setting in $config_map
  do
    local setting_key=${setting%=*}
    local setting_value=${setting#*=}
    local update="curl -u \"${AUTH_ARG}\" -H \"${http_hdr}\" -X POST -d \"key=${setting_key}&value=${setting_value}\" ${settings_url}"
    debug "update: \"${update}\""
    eval "${update}"
    unset setting_key setting_value update
  done
}

parseArgs(){

    FILENAME="$1"

    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
    key="$1"

    case "$key" in
        -f|--filename)
        FILENAME="$2"
        shift # past argument
        shift # past value
        ;;

        -h|--help)
        HELP=YES
        shift # past argument
        ;;

        --debug)
        DEBUG=YES
        shift # past argument
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters

    if [ -n "$HELP" ]; then
        usage
    fi

    if [[ -z "$FILENAME" ]]; then
        (>&2 echo "Error: --filename must be provided")
        usage
    fi
}

parseArgs "$@"
log "$program started"
log "Updating SonarQube Configuration"
#wait_for_service && \
update_init_admin_creds && \
update_config "${FILENAME}"
log "SonarQube Configuration Updated"
