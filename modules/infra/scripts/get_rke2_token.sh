#!/usr/bin/env bash

set -e

TOKEN=`ssh ubuntu@192.168.1.31 'sudo cat /var/lib/rancher/rke2/server/token'`

jq -n --arg token "$TOKEN" '{"token":$token}'
