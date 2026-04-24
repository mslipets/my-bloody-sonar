#!/bin/bash

export TESTS_DIR="$BATS_TEST_DIRNAME"
export TESTS_HOST_CONF_DIR="$TESTS_DIR/confdir"
export TESTS_CONTAINER_TESTS_DIR=/tests
export TESTS_CONTAINER_CONF_DIR=/confdir
export SONAR_DOCKER_NETWORK_NAME=docker-bridge
export SLEEP_TIME_BEFORE_CHECKS=${SLEEP_TIME_BEFORE_CHECKS:-25}

function touch_config(){
    mkdir -p "$TESTS_HOST_CONF_DIR"
    touch "$TESTS_HOST_CONF_DIR/config.yml"
}

function truncate_config(){
    truncate -s "$TESTS_HOST_CONF_DIR/config.yml"
}

function config_from_fixture(){
    fixture=$1
    cp "$fixture" "$TESTS_HOST_CONF_DIR/config.yml"
}

function run_script(){
    file=$1
    script=$2
    service=sonar
    docker_compose_exec "$file" $service $TESTS_CONTAINER_TESTS_DIR/run-test.sh "$TESTS_CONTAINER_TESTS_DIR/$script"
}

function docker_compose_up(){
    file=$1
    docker compose -f "$TESTS_DIR/$file" up -d -V
}

function docker_compose_down(){
    file=$1
    docker compose -f "$TESTS_DIR/$file" down -v --remove-orphans
}

function docker_compose_exec(){
    file=$1
    service=$2
    command="${@:3}"
    docker compose -f "$TESTS_DIR/$file" exec -T "$service" "$command"
}

function health_check(){
    url=$1
    timeout=${HEALTH_CHECK_TIMEOUT:-300}
    echo "checking $url (timeout ${timeout}s)"
    deadline=$(( $(date +%s) + timeout ))
    while ! curl -f -s "$url" > /dev/null; do
        if [[ $(date +%s) -ge $deadline ]]; then
            echo "health_check timed out after ${timeout}s: $url" >&2
            return 1
        fi
        sleep 5
    done
}

function create_docker_network(){
    for ctr in $(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$SONAR_DOCKER_NETWORK_NAME" 2>/dev/null); do
        docker network disconnect --force "$SONAR_DOCKER_NETWORK_NAME" "$ctr" 2>/dev/null || true
    done
    docker network rm "$SONAR_DOCKER_NETWORK_NAME" 2>/dev/null || true
    docker network create -d bridge --attachable "$SONAR_DOCKER_NETWORK_NAME"
    docker network ls | grep "$SONAR_DOCKER_NETWORK_NAME"
}

function destroy_docker_network(){
    docker network rm "$SONAR_DOCKER_NETWORK_NAME"
}