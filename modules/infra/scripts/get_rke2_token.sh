#!/usr/bin/env bash

set -e

eval "$(jq -r '@sh "upstream_master=\(.upstream_master)"')"

TOKEN=`ssh ubuntu@${upstream_master} 'sudo cat /var/lib/rancher/rke2/server/token'`

jq -n --arg token "$TOKEN" '{"token":$token}'
