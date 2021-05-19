##################
### PARAMETERS ###
##################

# Username and Password for an OpenShift user with cluster-admin privileges.
# cluster-admin privileges are required as this script deploys operators to
# watch all namespaces.
OCP_ADMIN_USER=${OCP_ADMIN_USER:=admin}
OCP_ADMIN_PASSWORD=${OCP_ADMIN_PASSWORD:=admin}
# if you change cluster name then you need to change the strimzi yaml files.
KAFKA_CLUSTER_NAME="my-kafka"
# Default name for the Apicurio Registry this use case deploys.
APICURIO_REGISTRY_NAME="my-apicurioregistry"
# project name / namespace where event streams or kafka is defined
YOUR_PROJECT_NAME="mysandbox"
KAFKA_NS=$YOUR_PROJECT_NAME
YOUR_ITEMS_TOPIC=jb-items
YOUR_INVENTORY_TOPIC=jb-inventory
