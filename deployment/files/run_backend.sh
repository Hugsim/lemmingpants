#!/bin/bash
# Inspiration: https://spin.atomicobject.com/2017/08/24/start-stop-bash-background-process/

set -eu

trap "exit" INT TERM ERR
trap "kill 0" EXIT

export PGRST_JWT_SECRET=`cat /usr/local/etc/secret_key.txt`

/etc/init.d/postgresql start
postgrest /usr/local/etc/lemmingpants.conf &

{ # I think this is one of my better hacks.
    export PGRST_SERVER_PORT=$PGRST_WS_SERVER_PORT
    postgres-websockets /usr/local/etc/lemmingpants.conf &
}

wait
