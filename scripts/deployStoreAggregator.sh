#!/bin/bash
scriptDir=$(dirname $0)

function deployStoreAggregator {
    export KAFKA_BOOTSTRAP_SERVERS=$1
    export YOUR_PROJECT_NAME=$2
    export ITEM_TOPIC=$4
    export STORE_INVENTORY_TOPIC=$3
    cat ${scriptDir}/../apps/store-aggregator/base/configmap.yaml | envsubst | \
            tee ${scriptDir}/../apps/store-aggregator/overlay/configmap.yaml >/dev/null

    oc apply -k ${scriptDir}/../apps/store-aggregator -n $YOUR_PROJECT_NAME
    echo "Wait for the store-aggregator microservice to be deployed..."
    oc wait pod --for=condition=Ready -l app.kubernetes.io/name=store-aggregator -n ${YOUR_PROJECT_NAME} --timeout=300s
    if [[ $? -gt 0 ]]; 
    then 
    echo "[ERROR] - An error occurred while deploying the store-aggregator microservice"; exit 1; 
    else 
    echo "Done"; 
    fi
}

# deployItemAggregator my-kafka-kafka-bootstrap.mysandbox.svc:9093 mysandbox
