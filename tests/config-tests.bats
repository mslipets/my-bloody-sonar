#!/usr/bin/env bats

load tests_helpers

COMPOSE_FILE=docker-compose-simple.yml

function curl_test(){
    run_script $COMPOSE_FILE scripts/config/${BATS_TEST_DESCRIPTION}Test.sh
}

@test ">>> setup config tests env" {
    touch_config
    create_docker_network

    JENKINS_ENV_CONFIG_YML_URL="file://${TESTS_CONTAINER_CONF_DIR}/conf" \
    docker_compose_up $COMPOSE_FILE

    health_check http://0.0.0.0:9000/login
}

@test "Sanity" {
    skip
    curl_test
}

@test "BasicConfig" {
    skip
    curl_test
}

@test "GuestAccess" {
    skip
    curl_test
}


@test "<<< teardown config tests env" {
    docker_compose_down $COMPOSE_FILE
    destroy_docker_network
    rm -rf $TESTS_HOST_CONF_DIR
}
