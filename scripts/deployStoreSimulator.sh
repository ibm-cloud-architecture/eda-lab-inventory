#!/bin/bash
scriptDir=$(dirname $0)

function deployStoreSimulatorApp {
    export TARGET_MSG=kafka
    export KAFKA_BOOTSTRAP_SERVERS=$1
    YOUR_PROJECT_NAME=$2
    cat ${scriptDir}/../apps/store-simulator/base/configmap.yaml | envsubst | \
            tee ${scriptDir}/../apps/store-simulator/overlay/configmap.yaml >/dev/null

    oc apply -k ${scriptDir}/../apps/store-simulator -n $YOUR_PROJECT_NAME
    echo "Wait for the Store simulator microservice to be deployed..."
    oc wait pod --for=condition=Ready -l app.kubernetes.io/name=store-simulator -n ${YOUR_PROJECT_NAME} --timeout=300s
    if [[ $? -gt 0 ]]; 
    then 
    echo "[ERROR] - An error occurred while deploying the Store simulator microservice"; exit 1; 
    else 
    echo "Done"; 
    fi
}

deployStoreSimulatorApp my-kafka-kafka-bootstrap.mysandbox.svc:9093 mysandbox
