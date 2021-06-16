#!/bin/bash

scriptDir=$(dirname $0)

##################
### PARAMETERS ###
##################

# Username and Password for an OpenShift user with cluster-admin privileges.
# cluster-admin privileges are required as this script deploys operators to
# watch all namespaces.
OCP_ADMIN_USER=${OCP_ADMIN_USER:=admin}
OCP_ADMIN_PASSWORD=${OCP_ADMIN_PASSWORD:=admin}

source ${scriptDir}/env-amq-streams.sh

###################################
### DO NOT EDIT BELOW THIS LINE ###
###################################
### EDIT AT YOUR OWN RISK      ####
###################################


function install_operator() {
### function will create an operator subscription to the openshift-operators
###          namespace for CR use in all namespaces
### parameters:
### $1 - operator name
### $2 - operator channel
### $3 - operator catalog source
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${1}
  namespace: openshift-operators
spec:
  channel: ${2}
  name: ${1}
  source: $3
  sourceNamespace: openshift-marketplace
  targetNamespaces: $4
EOF
}


############
### MAIN ###
############
source ${scriptDir}/login.sh
### Login
# Make sure we don't have more than 1 argument
if [[ $# -gt 1 ]];then
 echo "Usage: sh  `basename "$0"` [--skip-login]"
 exit 1
fi

validateLogin $1

if [[ $? -gt 0 ]]
then
    echo "[ERROR] - An error occurred while logging into your OpenShift cluster"
    exit 1
fi


### Strimzi operator version stability appears to be not so stable, so this will
### specify the latest manually verified operator version for a given OCP version
### instead of just the default "stable" stream.
OPERATOR_VERSION="stable"

if [[ -z "$(oc get -n openshift-operators subscription | grep amq-streams )" ]]
then
  echo "Install the Strimzi Operator ${OPERATOR_VERSION}"
  echo "-------------------------------------------------------"
  install_operator "amq-streams " "${OPERATOR_VERSION}" "redhat-operators" $YOUR_PROJECT_NAME
  ###TODO### Alternate implementation for `oc wait --for=condition=AtLatestKnown subscription/__operator_subscription__ --timeout 300s`
  echo "Waiting for strimzi-kafka-operator operator to be deployed..."
  counter=0
  desired_state="AtLatestKnown"
  until [[ ("$(oc get -n openshift-operators subscription amq-streams -o jsonpath="{.status.state}")" == "${desired_state}") || ( ${counter} == 60 ) ]]
  do
    ((counter++))
    echo -n "..."
    sleep 5
  done
  if [[ ${counter} == 60 ]]
  then
    echo
    echo "[ERROR] - Timeout occurred while deploying the Strimzi Kafka Operator"
    exit 1
  else
    echo "Done"
  fi

fi

cluster_present=$( oc get kafka | grep $KAFKA_CLUSTER_NAME)

if [[ -z $cluster_present ]]
then
  echo "Create a Kafka cluster"
  oc apply -k ${scriptDir}/../environments/amq-streams -n $YOUR_PROJECT_NAME
  echo -n "Waiting for the Kafka cluster to be available..."
  counter=0
  isKafkaReady="NotReady"
  until [[ ("${isKafkaReady}" == "Ready") || ( ${counter} == 60 ) ]]
  do
    isKafkaReady=`oc get kafkas.kafka.strimzi.io ${KAFKA_CLUSTER_NAME} -n ${YOUR_PROJECT_NAME} -o jsonpath="{.status.conditions[].type}" 2> /dev/null`
    echo -n "..."
    ((counter++))
    sleep 5
  done
  if [[ ${counter} == 60 ]]
  then
    echo
    echo "[ERROR] - Timeout occurred while deploying the Kafka Cluster"
    exit 1
  else
    echo "Done"
  fi
else
  echo "${KAFKA_CLUSTER_NAME} already present" 
fi
