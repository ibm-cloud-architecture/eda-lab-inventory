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

source ${scriptDir}/env-strimzi.sh

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
  namespace: ${3}
spec:
  channel: ${4}
  installPlanApproval: Automatic
  name: ${1}
  source: ${2}
  sourceNamespace: openshift-marketplace
  startingCSV: apicurio-registry.v0.0.4-v1.3.2.final
EOF
}

function create_operator_group {
### Function to create an Operator Group for the Apicurio Registry Operator to use
### parameters:
### $1 - openshift project
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${1}
  namespace: ${1}
spec:
  targetNamespaces:
  - ${1}
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

# Create an Operator Group so that the Apicurio Registry Operator finds a namespaced Operator Group
# for a namespaced Apicurio Registry Operator install
echo "Create the Operator Group"
create_operator_group "${YOUR_PROJECT_NAME}"

echo "Install the Apicurio Registry Operator"
install_operator "apicurio-registry" "community-operators" "${YOUR_PROJECT_NAME}" "alpha"

###TODO### Alternate implementation for `oc wait --for=state=AtLatestKnown subscription/apicurio-registry --timeout 300s`
echo -n "Wait for the Apicurio Registry Operator to be available..."
counter=0
desired_state="AtLatestKnown"
until [[ ("$(oc get subscription apicurio-registry -n ${YOUR_PROJECT_NAME} -o jsonpath="{.status.state}")" == "${desired_state}") || ( ${counter} == 60 ) ]]
do
  ((counter++))
  echo -n "..."
  sleep 5
done
if [[ ${counter} == 60 ]]
then
  echo
  echo "[ERROR] - Timeout occurred while deploying the Apicurio Registry Operator"
  exit 1
else
  echo "Done"
fi

oc apply -k ${scriptDir}/../environments/apicurio -n $YOUR_PROJECT_NAME

echo -n "Wait for the Apicurio registry to be deployed..."
counter=0
apicurioDCName=""
until [[ ( ! -z "${apicurioDCName}") || ( ${counter} == 60 ) ]]
do
  ((counter++))
  echo -n "..."
  sleep 5
  apicurioDCName="$(oc get apicurioregistry ${APICURIO_REGISTRY_NAME} -o jsonpath="{.status.deploymentName}" 2>/dev/null)"
done
if [[ ${counter} == 60 ]]
then
  echo
  echo "[ERROR] - Timeout occurred while waiting for the Apicurio Registry to be deployed"
  exit 1
else
  echo "Done"
fi

# As soon as the ApicurioRegistry object gets the deploymentConfig name, it is marked as Available so the following oc wait is useless
# echo "Waiting for Apicurio registry to be available..."
# oc wait --for=condition=Available dc/${apicurioDCName} --timeout 300s