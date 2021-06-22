#!/bin/bash
scriptDir=$(dirname $0)

##################
### PARAMETERS ###
##################

### Make sure you have the appropriate values for the following variables in the env-strimzi.sh file
# YOUR_PROJECT_NAME="mysandbox"              # Default OpenShift project where this inventory use case will be deployed into.
# KAFKA_CLUSTER_NAME="my-kafka"              # Default name for the Kafka Cluster this use case deploys. 
# APICURIO_REGISTRY_NAME="my-apicurioregistry" # Default name for the Apicurio Registry this use case deploys.

# Load environment variables
source ${scriptDir}/env-amq-streams.sh

###################################
### DO NOT EDIT BELOW THIS LINE ###
###################################
### EDIT AT YOUR OWN RISK !!!  ####
###################################
### If values below are changed, review not only this script but also
### the yaml files under /apps and /environmnets
SA_NAME="inventory-solution-sa"
SCRAM_USER="scram-user"
TLS_USER="tls-user"
KAFKA_CONNECT_CLUSER_NAME="my-connect-cluster"

############
### MAIN ###
############

# Make sure we don't have more than 1 argument
if [[ $# -gt 1 ]];then
 echo "Usage: sh  `basename "$0"` [--skip-login]"
 exit 1
fi
clear
echo "##########################################################"
echo "## Real time inventory solution Deployment ##"
echo "##########################################################"

################
### 1. Login ###
################
echo
echo "1. Log into your OpenShift cluster"
echo "----------------------------------"

# Load login utilities
source ${scriptDir}/login.sh

# Log into your OCP cluster
validateLogin $1

if [[ $? -gt 0 ]]
then
    echo "[ERROR] - An error occurred while logging into your OpenShift cluster"
    exit 1
fi

################################################
### 2. OpenShift Project and Service Account ###
################################################
# Load project and SA utilities
source ${scriptDir}/defineProject.sh
echo
echo "2. OpenShift project and Service Account"
echo "----------------------------------------"
# Create the Project, Service Account and appropriate admin policies
createProjectAndServiceAccount ${YOUR_PROJECT_NAME} ${SA_NAME}
if [[ $? -gt 0 ]]
then 
    echo "[ERROR] - An error occurred while creating your OpenShift project and Service Account"
    exit 1
fi

########################
### 3. Kafka Cluster ###
########################
echo
echo "3. Deploy the Kafka Cluster"
echo "---------------------------"

### Kafka Cluster 
echo "Check if the Kafka Cluster ${KAFKA_CLUSTER_NAME} already exists..."
if [[ -z $(oc get kafkas.kafka.strimzi.io ${KAFKA_CLUSTER_NAME} -n ${YOUR_PROJECT_NAME} 2> /dev/null) ]]
then
    echo "Kafka Cluster does not exist yet."
    echo "--> Create Kafka Cluster with Strimzi..."
    ${scriptDir}/deployAMQStreams.sh --skip-login
    if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while deploying the Strimzi Kafka Cluster"; exit 1; fi
else
    echo "--> Kafka Cluster ${KAFKA_CLUSTER_NAME} already exists"
fi

### Kafka Cluster Certificate
echo
echo "Check if the Kafka Cluster CA certificate secret exists"
if [[ -z $(oc get secret kafka-cluster-ca-cert 2>/dev/null) ]]
then
    echo "Kafka Cluster CA certificate secret not found. Create it"
    oc get secret ${KAFKA_CLUSTER_NAME}-cluster-ca-cert -n ${YOUR_PROJECT_NAME} -o json | jq -r '.metadata.name="kafka-cluster-ca-cert"' | jq --arg project_name "${YOUR_PROJECT_NAME}" -r '.metadata.namespace=$project_name' | oc apply -f -
    if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while creating the Kafka Cluster CA certificate secret"; exit 1; else echo " --> Done"; fi
else
    echo "--> Kafka Cluster CA certificate secret already exists"
fi

### Create Kafka Topic
source ${scriptDir}/defineTopic.sh
echo
echo "work on Kafka Topics..."
echo " - Check if ${YOUR_ITEMS_TOPIC} topic"
if [[ -z $(oc get kafkatopic ${YOUR_ITEMS_TOPIC} 2>/dev/null) ]]
then
    defineTopic ${KAFKA_CLUSTER_NAME} ${YOUR_ITEMS_TOPIC}
else
    echo " --> exists"
fi

echo " - Check if ${YOUR_ITEM_INVENTORY_TOPIC} topic"
if [[ -z $(oc get kafkatopic ${YOUR_ITEM_INVENTORY_TOPIC} 2>/dev/null) ]]
then
    defineTopic ${KAFKA_CLUSTER_NAME} ${YOUR_ITEM_INVENTORY_TOPIC}
else
    echo " --> exists"
fi

echo " - Check if ${YOUR_STORE_INVENTORY_TOPIC} topic"
if [[ -z $(oc get kafkatopic ${YOUR_STORE_INVENTORY_TOPIC} 2>/dev/null) ]]
then
    defineTopic ${KAFKA_CLUSTER_NAME} ${YOUR_STORE_INVENTORY_TOPIC}
else
    echo " --> exists"
fi

### Kafka Environment Configmap
echo
echo "Create Kafka Environment configmap"
kafka_cluster_internal_listener=`oc get kafkas.kafka.strimzi.io ${KAFKA_CLUSTER_NAME} -o jsonpath="{.status.listeners[?(@.type=='tls')].bootstrapServers}"`
kafka_cluster_external_listener=`oc get kafkas.kafka.strimzi.io ${KAFKA_CLUSTER_NAME} -o jsonpath="{.status.listeners[?(@.type=='external')].bootstrapServers}"`
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-env-cm
data:
  KAFKA_BOOTSTRAP_SERVERS: ${kafka_cluster_internal_listener}
  KAFKA_BOOTSTRAP_SERVERS_EXT: ${kafka_cluster_external_listener}
  ITEMS_TOPIC: ${YOUR_ITEMS_TOPIC}
  ITEM_INVENTORY_TOPIC:  ${YOUR_ITEM_INVENTORY_TOPIC}
  STORE_INVENTORY_TOPIC: ${YOUR_STORE_INVENTORY_TOPIC}
EOF
if [[ $? -gt 0 ]]; 
then 
    echo "[ERROR] - An error occurred while creating the Kafka Environment configmap"; 
    exit 1; 
else 
    echo "--> Done"; 
fi

############################
### 4. Apicurio Registry ###
############################
# not needed yet

#####################################################
### 5. Store simulator app ###
#####################################################
echo
echo "5. Store simulator app "
echo "----------------------------------------------------------"
source ${scriptDir}/deployStoreSimulator.sh
deployStoreSimulatorApp $kafka_cluster_internal_listener $YOUR_ITEMS_TOPIC $YOUR_PROJECT_NAME

#####################################################
### 6. Item aggregator app ###
#####################################################
echo
echo "6. Item aggregator app "
echo "----------------------------------------------------------"
echo "Deploy the Item aggregator microservice"
source ${scriptDir}/deployItemAggregator.sh
deployItemAggregator $kafka_cluster_internal_listener $YOUR_PROJECT_NAME $YOUR_ITEM_INVENTORY_TOPIC $YOUR_ITEMS_TOPIC

#####################################################
### 7. Store aggregator app ###
#####################################################
echo
echo "7. Store aggregator app "
echo "----------------------------------------------------------"
echo "Deploy the Store aggregator microservice"
source ${scriptDir}/deployStoreAggregator.sh
deployStoreAggregator $kafka_cluster_internal_listener $YOUR_PROJECT_NAME $YOUR_STORE_INVENTORY_TOPIC $YOUR_ITEMS_TOPIC

echo
echo "********************"
echo "** CONGRATULATIONS!! You have successfully deployed the realtime inventory use case."
echo "********************"
echo
echo "You can now jump to the demo section for this use case at https://ibm-cloud-architecture.github.io/refarch-eda/scenarios/realtime-inventory//#demonstration-script"