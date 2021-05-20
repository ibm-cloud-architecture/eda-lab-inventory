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
source ${scriptDir}/env-strimzi.sh

###################################
### DO NOT EDIT BELOW THIS LINE ###
###################################
### EDIT AT YOUR OWN RISK !!!  ####
###################################
### If values below are changed, review not only this script but also
### the yaml files under /apps and /environmnets
SA_NAME="inventory-runtime"
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
echo
echo "2. Create your OpenShift project and Service Account"
echo "----------------------------------------------------"

# Load project and SA utilities
source ${scriptDir}/defineProject.sh

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
echo "3. Deploy the Kafka Cluser"
echo "--------------------------"

### Kafka Cluster 
echo "Check if the Kafka Cluster ${KAFKA_CLUSTER_NAME} already exists"
if [[ -z $(oc get kafkas.kafka.strimzi.io ${KAFKA_CLUSTER_NAME} -n ${YOUR_PROJECT_NAME} 2> /dev/null) ]]
then
    echo "Kafka Cluster does not exist yet"
    echo "Create Kafka Cluster with Strimzi"
    ${scriptDir}/deployStrimzi.sh --skip-login
    if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while deploying the Strimzi Kafka Cluster"; exit 1; fi
else
    echo "Kafka Cluster ${KAFKA_CLUSTER_NAME} already exists"
fi

### Kafka Cluster Certificate
echo
echo "Check if the Kafka Cluster CA certificate secret exists"
if [[ -z $(oc get secret kafka-cluster-ca-cert 2>/dev/null) ]]
then
    echo "Kafka Cluster CA certificate secret not found. Create it"
    oc get secret ${KAFKA_CLUSTER_NAME}-cluster-ca-cert -n ${YOUR_PROJECT_NAME} -o json | jq -r '.metadata.name="kafka-cluster-ca-cert"' | jq --arg project_name "${YOUR_PROJECT_NAME}" -r '.metadata.namespace=$project_name' | oc apply -f -
    if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while creating the Kafka Cluster CA certificate secret"; exit 1; else echo "Done"; fi
else
    echo "Kafka Cluster CA certificate secret already exists"
fi

### Create Kafka Topic
source ${scriptDir}/defineTopic.sh
echo
echo "Create Kafka Topics"
if [[ -z $(oc get kafkatopic ${YOUR_ITEMS_TOPIC} 2>/dev/null) ]]
then
    defineTopic ${KAFKA_CLUSTER_NAME} ${YOUR_ITEMS_TOPIC}
fi
if [[ -z $(oc get kafkatopic ${YOUR_INVENTORY_TOPIC} 2>/dev/null) ]]
then
    defineTopic ${KAFKA_CLUSTER_NAME} ${YOUR_INVENTORY_TOPIC}
fi

### Kafka Topics Configmap
echo
echo "Create Kafka Topics configmap"
kafka_cluster_internal_listener=`oc get kafkas.kafka.strimzi.io ${KAFKA_CLUSTER_NAME} -o jsonpath="{.status.listeners[?(@.type=='tls')].bootstrapServers}"`
kafka_cluster_external_listener=`oc get kafkas.kafka.strimzi.io ${KAFKA_CLUSTER_NAME} -o jsonpath="{.status.listeners[?(@.type=='external')].bootstrapServers}"`
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-topics-cm
data:
  KAFKA_BOOTSTRAP_SERVERS: ${kafka_cluster_internal_listener}
  KAFKA_BOOTSTRAP_SERVERS_EXT: ${kafka_cluster_external_listener}
  ITEMS_TOPIC: ${YOUR_ITEMS_TOPIC}
  INVENTORY_TOPIC:  ${YOUR_INVENTORY_TOPIC}
EOF
if [[ $? -gt 0 ]]; 
then 
    echo "[ERROR] - An error occurred while creating the Kafka Topics configmap"; 
    exit 1; 
else 
    echo "Done"; 
fi

############################
### 4. Apicurio Registry ###
############################
echo
echo "4. Deploy the Apicurio Registry"
echo "-------------------------------"
### Apicurio Registry
echo "Check if the Apicurio Registry ${APICURIO_REGISTRY_NAME} already exists"
if [[ -z $(oc get apicurioregistries.apicur.io ${APICURIO_REGISTRY_NAME} -n ${YOUR_PROJECT_NAME} 2> /dev/null) ]]
then
    echo "Apicurio Registry does not exist yet"
    echo "Create Apicurio Registry"
    ${scriptDir}/deployApicurio.sh --skip-login
    # Check the Apicurio Registry deployment went fine
    if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while deploying the Apicurio Registry" ; exit 1; fi
    ### Avro Schemas
    # Get Apricurio Registry url
    # The status.host parameter of the Apicurio Registry resource takes other values before taking the definite route.
    # ar_url=`oc get apicurioregistries.apicur.io ${APICURIO_REGISTRY_NAME} -n ${YOUR_PROJECT_NAME} -o jsonpath="{.status.host}"`
    echo -n "Waiting for the Apicurio Registry to be accessible..."
    ar_route=""
    counter=0
    until [[ ( ! -z "${ar_route}") || ( ${counter} == 20 ) ]]
    do
        ((counter++))
        echo -n "..."
        sleep 5
        ar_route=`oc get routes | grep ${APICURIO_REGISTRY_NAME} | awk '{print $1}'`
    done

    if [[ ${counter} == 20 ]]
    then
        echo
        echo "[ERROR] - Timeout occurred while waiting for the Apicurio Registry to be accessible"
        exit 1
    else
        ar_host_url=`oc get route ${ar_route} -o jsonpath="{.status.ingress[].host}"`
        ar_routerCanonicalHostname_url=`oc get route ${ar_route} -ojsonpath="{.status.ingress[].routerCanonicalHostname}"`
        ar_url="${ar_host_url}.${ar_routerCanonicalHostname_url}"
        counter=0
        until [[ ( "${ar_url}" == "${ar_host_url}" ) || ( ${counter} == 20 ) ]]
        do
            ((counter++))
            echo -n "..."
            sleep 5
            ar_route=`oc get routes | grep ${APICURIO_REGISTRY_NAME} | awk '{print $1}'`
            ar_host_url=`oc get route ${ar_route} -o jsonpath="{.status.ingress[].host}" 2>/dev/null`
        done
        if [[ ${counter} == 20 ]]
        then
            echo
            echo "[ERROR] - Timeout occurred while waiting for the Apicurio Registry to be accessible"
            exit 1
        else
            echo "Done"
        fi
        echo "Your Apicurio Registry is accessible at http://${ar_url}"
        register_avro_schemas "${ar_url}"
    fi

else
    echo "Apicruio Registry ${APICURIO_REGISTRY_NAME} already exists"
    ar_url=`oc get apicurioregistries.apicur.io ${APICURIO_REGISTRY_NAME} -o jsonpath="{.status.host}"`
    delete_avro_schemas "${ar_url}"
    register_avro_schemas "${ar_url}"
fi

### Create Schema Registry secret
echo
echo "Create the Schema Registry secret..."
ar_service=`oc get apicurioregistry ${APICURIO_REGISTRY_NAME} -o jsonpath="{.status.serviceName}"`
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kafka-schema-registry
stringData:
  SCHEMA_REGISTRY_URL: http://${ar_service}:8080/api
EOF
if [[ $? -gt 0 ]]; 
then 
echo "[ERROR] - An error occurred while creating the Schema Registry secret"; 
exit 1; 
else 
echo "Done"; 
fi

### Create Schema Registry for Confluent compatibility secret
echo
echo "Create the Schema Registry for Confluent compatibility secret..."
ar_service=`oc get apicurioregistry ${APICURIO_REGISTRY_NAME} -o jsonpath="{.status.serviceName}"`
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kafka-schema-registry-ccompat
stringData:
  SCHEMA_REGISTRY_URL: http://${ar_service}:8080/api/ccompat
EOF

if [[ $? -gt 0 ]]; 
then 
    echo "[ERROR] - An error occurred while creating the Schema Registry for Confluent compatibility secret"; 
    exit 1; 
else 
    echo "Done"; 
fi


#####################################################
### 5. Store simulator app ###
#####################################################
echo
echo "5. Store simulator app "
echo "----------------------------------------------------------"
echo "Deploy the Store simulator microservice"
source ${scriptDir}/deployStoreSimulator.sh
deployStoreSimulatorApp $kafka_cluster_internal_listener $YOUR_PROJECT_NAME

#####################################################
### 6. Item aggregator app ###
#####################################################
echo
echo "6. Item aggregator app "
echo "----------------------------------------------------------"
echo "Deploy the Item aggregator microservice"
source ${scriptDir}/deployItemAggregator.sh
deployItemAggregator $kafka_cluster_internal_listener $YOUR_PROJECT_NAME

echo
echo "********************"
echo "** CONGRATULATIONS!! You have successfully deployed the realtime inventory use case."
echo "********************"
echo
echo "You can now jump to the demo section for this use case at https://ibm-cloud-architecture.github.io/refarch-eda/scenarios/realtime-inventory//#demonstration-script"