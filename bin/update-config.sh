#!/bin/bash -e

program=$0
script_dir=$(
    cd $(dirname "$0")
    pwd
)

http_hdr="Content-Type: application/x-www-form-urlencoded"
sonar_url="http://localhost:9000"
default_credentials="admin:admin"
token_file="$TOKEN_FILE_LOCATION"
token_name=$(basename "$program")
sonar_properties_file="$SONARQUBE_HOME/conf/sonar.properties"

usage() {
    cat <<EOF
Usage: $program <CONFIG_FILE_LOCATION>
Options:
-f, --filename                              - file to be parsed and used as config source.
                                              (same as $program <CONFIG_FILE_LOCATION>)
--debug                                     - Log debug (Default: false)

EOF
    exit 1
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

debug() {
    [[ "$DEBUG" == "YES" ]] && log "$@"
}

function error_exit() {
    echo "$1" 1>&2
    exit 1
}

function check_deps() {
    errors_list=''
    for i in $1; do
        test -f "$(which "$i")" || errors_list+="$i command not detected in path, please install it\n"
    done
    test -z "$errors_list" || error_exit "$errors_list"
}

wait_for_service() {
    health=$(curl -sL -w "%{http_code}\n" "${sonar_url}/api/system/status" -o /dev/null)
    while [[ $health -ne "200" ]]; do
        sleep 60
        health=$(curl -sL -w "%{http_code}\\n" "${sonar_url}/api/system/status" -o /dev/null)
        debug "web service responds $health"
    done
    debug "sonar web service is up"
}

get_auth() {
    if [[ -z "$AUTH_ARG" ]]; then
        AUTH_ARG=""
        if [[ -f "${token_file}" ]]; then
            AUTH_ARG="$(cat "${token_file}"):"
        else
            AUTH_ARG="${SONAR_ADMIN_USERNAME}:${SONAR_ADMIN_PASSWORD}"
        fi
    fi
}

#INFO: https://next.sonarqube.com/sonarqube/web_api/api/user_tokens/generate
generate_token() {
    if [[ ! -f "${token_file}" ]]; then
        curl -s -u "${SONAR_ADMIN_USERNAME}":"${SONAR_ADMIN_PASSWORD}" -H "${http_hdr}" \
            -X POST -d "login=${SONAR_ADMIN_USERNAME}&name=${token_name}" \
            "${sonar_url}/api/user_tokens/generate" -o - | jq -r '.token' >>"${token_file}"

        if [[ $token_name != $(curl -s -u "${SONAR_ADMIN_USERNAME}":"${SONAR_ADMIN_PASSWORD}" -H "${http_hdr}" \
            "${sonar_url}/api/user_tokens/search" -o - |
            jq -r ".userTokens[] | select(.name==\"${token_name}\") | .name") ]]; then
            error_exit "User token for \"${SONAR_ADMIN_USERNAME}\" name: $token_name generation failed!"
        else
            unset SONAR_ADMIN_USERNAME SONAR_ADMIN_PASSWORD
        fi
    fi
}

is_admin_unsecured() {
    status=$(curl -sL -w "%{http_code}\n" -u "${default_credentials}" -H "${http_hdr}" "${sonar_url}/api/user_tokens/search" -o /dev/null)
    debug "Access with default admin credentials status: $status"
    if [[ $status == "200" ]]; then return 0; else return 1; fi
}

secure_admin_credentials() {
    if [[ $(is_admin_unsecured) ]]; then
        curl -s -u "${default_credentials}" -H "${http_hdr}" \
            -X POST -d "login=${SONAR_ADMIN_USERNAME}&name=Admin&password=${SONAR_ADMIN_PASSWORD}&password_confirmation=${SONAR_ADMIN_PASSWORD}" \
            "${sonar_url}/api/users/create" -o /dev/null &&
            curl -s -u "${default_credentials}" -H "${http_hdr}" \
                -X POST -d "name=sonar-administrators&login=${SONAR_ADMIN_USERNAME}" \
                "${sonar_url}/api/user_groups/add_user" -o /dev/null &&
            curl -s -u "${SONAR_ADMIN_USERNAME}":"${SONAR_ADMIN_PASSWORD}" -H "${http_hdr}" \
                -X POST -d "login=admin" "${sonar_url}/api/users/deactivate" -o /dev/null &&
            debug "default admin user disabled." &&
            generate_token
    fi
}

update_sonar_properties() {
    local setting="$1"
    local file="$sonar_properties_file"
    debug "updating $(basename "$sonar_properties_file"): ${setting}"
    local setting_key="${setting%=*}"
    if grep -q "$setting_key" "$file"; then
        debug "sed -i 's@^.*\b'\"$setting_key\"'\b.*\$@'\"$setting\"'@' $file"
        sed -i 's@^.*\b'"$setting_key"'\b.*$@'"$setting"'@' "$file"
    else
        echo "$property_line" >>"$file"
    fi
}

update_config() {
    get_auth
    local settings_url="${sonar_url}/api/settings/set"

    SAVEIFS=$IFS                                                 # Save current IFS
    IFS=$'\n'                                                    # Change IFS to new line
    config_map=($("${script_dir}/parseconfig.py" --source "$1")) # split to array $config_map
    IFS=$SAVEIFS                                                 # Restore IFS

    for setting in "${config_map[@]}"; do
        if [[ "$setting" == "ldap"* ]]; then
            update_sonar_properties "$setting"
        else
            local setting_key="${setting%=*}"
            local setting_value="${setting#*=*}"
            local update="curl -s -u \"${AUTH_ARG}\" -H \"${http_hdr}\" -X POST -d \"key=${setting_key}&value=${setting_value}\" ${settings_url} -o /dev/null"
            debug "update: \"${update}\""
            eval "${update}"
        fi
    done
}

parse_args() {
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

    if [[ -n "$HELP" ]]; then
        usage
    fi

    if [[ -z "$FILENAME" ]]; then
        (echo >&2 "Error: \$FILENAME must be provided")
        usage
    fi
}

check_deps "jq"
parse_args "$@"
log "$(basename "$program") started"
log "Updating SonarQube Configuration"
wait_for_service &&
    secure_admin_credentials &&
    update_config "${FILENAME}"
log "SonarQube Configuration Updated"
