#!/bin/bash

function defineTopic {
    CLUSTER_NAME=$1
    TOPIC_NAME=$2
    oc apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: $TOPIC_NAME
  labels:
    strimzi.io/cluster: $CLUSTER_NAME
spec:
  partitions: 3
  replicas: 3
EOF
}