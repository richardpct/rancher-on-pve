#!/usr/bin/env bash

set -e

eval "$(jq -r '@sh "local_server=\(.local_server)"')"

TOKEN=`ssh ubuntu@${local_server} 'sudo cat /var/lib/rancher/rke2/server/token'`

jq -n --arg token "$TOKEN" '{"token":$token}'
