#!/bin/bash
scriptDir=$(dirname $0)

function deployItemAggregator {
    export KAFKA_BOOTSTRAP_SERVERS=$1
    YOUR_PROJECT_NAME=$2
    cat ${scriptDir}/../apps/item-aggregator/base/configmap.yaml | envsubst | \
            tee ${scriptDir}/../apps/item-aggregator/overlay/configmap.yaml >/dev/null

    oc apply -k ${scriptDir}/../apps/item-aggregator -n $YOUR_PROJECT_NAME
    echo "Wait for the item-aggregator microservice to be deployed..."
    oc wait pod --for=condition=Ready -l app.kubernetes.io/name=item-aggregator -n ${YOUR_PROJECT_NAME} --timeout=300s
    if [[ $? -gt 0 ]]; 
    then 
    echo "[ERROR] - An error occurred while deploying the item-aggregator microservice"; exit 1; 
    else 
    echo "Done"; 
    fi
}

# deployItemAggregator my-kafka-kafka-bootstrap.mysandbox.svc:9093 mysandbox
