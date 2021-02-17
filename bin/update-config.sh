#!/bin/bash -e

program=$0
script_dir=$(cd $(dirname "$0"); pwd)

http_hdr="Content-Type: application/x-www-form-urlencoded"
sonar_url="http://localhost:9000"
default_credentials="admin:admin"

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

function error_exit(){
    echo "$1" 1>&2
    exit 1
}

function check_deps(){
    errors_list=''
    for i in $1; do
        test -f "$(which "$i")" || errors_list+="$i command not detected in path, please install it\n"
    done
    test -z "$errors_list" || error_exit "$errors_list"
}

wait_for_service(){
    health=$(curl -sL -w "%{http_code}\n" "${sonar_url}/api/system/status" -o /dev/null)
    while [[ $health -ne "200" ]]; do
        sleep 300
        health=$(curl -sL -w "%{http_code}\\n" "${sonar_url}/api/system/status" -o /dev/null)
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

#INFO: https://next.sonarqube.com/sonarqube/web_api/api/user_tokens/generate
generate_token(){
    token_file="$TOKEN_FILE_LOCATION"
    token_name="${program}"

    curl -s -u "${SONAR_ADMIN_USERNAME}":"${SONAR_ADMIN_PASSWORD}" -H "${http_hdr}" \
        -X POST -d "login=${SONAR_ADMIN_USERNAME}&name=${token_name}" \
        "${sonar_url}/api/user_tokens/generate" | jq -r '.token' >> "${token_file}"

    if [[ $program != $(curl -u "${SONAR_ADMIN_USERNAME}":"${SONAR_ADMIN_PASSWORD}" -H "${http_hdr}" \
        "${sonar_url}/api/user_tokens/search" |
        jq -r ".userTokens[] | select(.name==\"${program}\") | .name") ]]; then
        error_exit "User token for \"${SONAR_ADMIN_USERNAME}\" name: $program generation failed!"
    else
        unset SONAR_ADMIN_USERNAME SONAR_ADMIN_PASSWORD
    fi
}

is_admin_unsecured(){
    status=$(curl -sL -w "%{http_code}\n" -u "${default_credentials}" -H "${http_hdr}" "${sonar_url}/api/user_tokens/search" -o /dev/null)
    debug "Access with default admin credentials status: $status"
    if [[ $status == "200" ]]; then return 0; else return 1; fi
}

secure_admin_credentials(){
    if [[ $(is_admin_unsecured) ]]; then
        curl -u admin:admin -H "${http_hdr}" \
                -X POST -d "login=${SONAR_ADMIN_USERNAME}&name=Admin&password=${SONAR_ADMIN_PASSWORD}&password_confirmation=${SONAR_ADMIN_PASSWORD}" \
                "${sonar_url}/api/users/create" &&
        curl -u admin:admin -H "${http_hdr}" \
                -X POST -d "name=sonar-administrators&login=${SONAR_ADMIN_USERNAME}" \
                "${sonar_url}/api/user_groups/add_user" &&
        curl -u "${SONAR_ADMIN_USERNAME}":"${SONAR_ADMIN_PASSWORD}" -H "${http_hdr}" \
                -X POST -d "login=admin" "${sonar_url}/api/users/deactivate"
        generate_token
    fi
}

update_config(){
    get_auth
    local settings_url="${sonar_url}/api/settings/set"

    SAVEIFS=$IFS   # Save current IFS
    IFS=$'\n'      # Change IFS to new line
    config_map=($("${script_dir}/parseconfig.py" --source "$1")) # split to array $config_map
    IFS=$SAVEIFS   # Restore IFS

    for setting in "${config_map[@]}"; do
        local setting_key="${setting%=*}"
        local setting_value="${setting#*=*}"
        local update="curl -u \"${AUTH_ARG}\" -H \"${http_hdr}\" -X POST -d \"key=${setting_key}&value=${setting_value}\" ${settings_url}"
        debug "update: \"${update}\""
        eval "${update}"
        unset setting_key setting_value update
    done
}

parse_args(){
    FILENAME="$1"
    POSITIONAL=()
    while [[ $# -gt 0 ]]; do
        key="$1"

        case "$key" in
        -f | --filename)
            FILENAME="$2"
            shift # past argument
            shift # past value
            ;;

        -h | --help)
            HELP=YES
            shift # past argument
            ;;

        --debug)
            DEBUG=YES
            shift # past argument
            ;;
        *) # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift              # past argument
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

check_deps "jq"
parse_args "$@"
log "$program started"
log "Updating SonarQube Configuration"
wait_for_service &&
secure_admin_credentials &&
update_config "${FILENAME}"
log "SonarQube Configuration Updated"
