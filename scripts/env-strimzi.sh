##################
### PARAMETERS ###
##################

# Username and Password for an OpenShift user with cluster-admin privileges.
# cluster-admin privileges are required as this script deploys operators to
# watch all namespaces.
OCP_ADMIN_USER=${OCP_ADMIN_USER:=admin}
OCP_ADMIN_PASSWORD=${OCP_ADMIN_PASSWORD:=admin}
# project name / namespace where event streams or kafka is defined
YOUR_PROJECT_NAME="rt-inventory"
# if you change cluster name then you need to change the strimzi yaml files.
KAFKA_CLUSTER_NAME="my-kafka"
KAFKA_NS=$YOUR_PROJECT_NAME
YOUR_ITEMS_TOPIC=items
YOUR_ITEM_INVENTORY_TOPIC=item.inventory
YOUR_STORE_INVENTORY_TOPIC=store.inventory
# Default name for the Apicurio Registry this use case deploys.
# Not used in current version
APICURIO_REGISTRY_NAME="my-apicurioregistry"
