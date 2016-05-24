#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

deploy_image() {
    autorization_token=$(aws ecr get-authorization-token --registry-ids 792082350620 --output text --query authorizationData[].authorizationToken | base64 --decode | cut -d: -f2)
    docker login -u AWS -p $autorization_token -e none https://792082350620.dkr.ecr.us-west-2.amazonaws.com
    docker tag webapp-repository:$CIRCLE_SHA1 792082350620.dkr.ecr.us-west-2.amazonaws.com/webapp-repository:latest
    docker push 792082350620.dkr.ecr.us-west-2.amazonaws.com/webapp-repository:latest
}

# reads $CIRCLE_SHA1, $host_port
# sets $task_def
make_task_def() {

    task_template='[
	{
	    "name": "start",
	    "image": "792082350620.dkr.ecr.us-west-2.amazonaws.com/webapp-repository:latest",
	    "essential": true,
	    "memory": 200,
	    "cpu": 10
	}
    ]'

    task_def=$(printf "$task_template")

}

# reads $family
# sets $revision
register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $family | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

deploy_cluster() {

    host_port=80
    family="webapp-update"

    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster webapp-cluster --service webapp-service --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..30}; do
        if stale=$(aws ecs describe-services --cluster webapp-cluster --services webapp-ecs-service | \
                       $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
            echo "Waiting for stale deployments:"
            echo "$stale"
            sleep 5
        else
            echo "Deployed!"
            return 0
        fi
    done
    echo "Service update took too long."
    return 1
}

deploy_image
deploy_cluster
