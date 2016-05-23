#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

deploy_image() {
    autorization_token=$(aws ecr get-authorization-token --registry-ids 792082350620 --output text --query authorizationData[].authorizationToken | base64 --decode | cut -d: -f2)
    docker login -u AWS -p $autorization_token -e none https://792082350620.dkr.ecr.us-west-2.amazonaws.com
    docker tag webapp-repository:latest 792082350620.dkr.ecr.us-west-2.amazonaws.com/webapp-repository:latest
    docker push 792082350620.dkr.ecr.us-west-2.amazonaws.com/webapp-repository
}

deploy_image
