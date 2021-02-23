#!/bin/bash -e

script_dir=$(cd $(dirname "$0"); pwd)
token_file="$TOKEN_FILE_LOCATION"
AUTH_ARG=""

if [ -f "$token_file" ]; then
    AUTH_ARG="-auth $(cat "$token_file")"
fi

echo "Running test $1"
    echo '#TODO implement eval tes script! https://github.com/mslipets/my-bloody-sonar/issues/2'
echo "Running test $1... done"
