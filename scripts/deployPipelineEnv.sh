#!/bin/bash
scriptDir=$(dirname $0)

############
### Define pipeline project with Tekton Operator ###
############
# Load environment variables
source ${scriptDir}/env-amq-streams.sh


function createPipelineProjectAndServiceAccount {
    YOUR_PROJECT_NAME=$1
    SA_NAME=$2
    ###############################
    # Create project if not exist #
    ###############################
    echo "Check if $YOUR_PROJECT_NAME OpenShift project exists"
    PROJECT_EXIST=$(oc get ns $YOUR_PROJECT_NAME 2> /dev/null)
    if [[ -z  $PROJECT_EXIST ]]
    then
        echo "--> Create $YOUR_PROJECT_NAME OpenShift project"
        oc new-project ${YOUR_PROJECT_NAME}
        if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while creating your OpenShift project"; exit 1; else echo " --> Done"; fi
    else
      echo "--> OpenShift Project ${YOUR_PROJECT_NAME} already exists"
    fi
    oc project ${YOUR_PROJECT_NAME}

    echo "Check if $SA_NAME service account exists"
    if [[ -z $(oc get sa | grep $SA_NAME) ]]
    then
      echo "--> Create $SA_NAME Service Account"
      oc apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SA_NAME
EOF
      if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while creating your OpenShift Service Account"; exit 1; else echo " --> Done"; fi
      echo "Create appropriate admin policies for the Service Account"
      oc adm policy add-scc-to-user anyuid -z $SA_NAME -n ${YOUR_PROJECT_NAME}
      if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while creating the appropriate admin policies for the Service Account"; exit 1; else echo " --> Done"; fi
    else
      echo "--> Service Account $SA_NAME already exists"
    fi

    echo " --> Create role binding"
    oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: inventory-view
roleRef:
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
  name: view
subjects:
- kind: ServiceAccount
  name: $SA_NAME
EOF
}

OPERATOR_NAME=openshift-pipelines-operator-rh
source $scriptDir/defineOperator.sh

# validate operator present
pipeline_operator=$(oc get operator | grep $OPERATOR_NAME)
if [[ -z $pipeline_operator ]]
then
  echo "--> Install Pipeline operator"
  oc apply -f $scriptDir/../environments/openshift-pipelines/operator.yaml
  waitUntilOperatorReady $OPERATOR_NAME
else
  echo "OPERATOR_NAME Operator already presents"
fi

source $scriptDir/env-amq-streams.sh
echo "Assess if pipeline project exists"
pipeline_project=$(oc get projects | grep $YOUR_PROJECT_NAME-pipe)
if [[ -z $pipeline_project ]]
then
  echo "--> Create $YOUR_PROJECT_NAME-pipe OpenShift project"
  oc new-project ${YOUR_PROJECT_NAME}-pipe
  if [[ $? -gt 0 ]]; then echo "[ERROR] - An error occurred while creating your OpenShift project"; exit 1; else echo " --> Done"; fi
else
  echo "$YOUR_PROJECT_NAME-pipe already presents"
fi

echo "Define service account"
SA=$(oc get sa build-robot -n ${YOUR_PROJECT_NAME}-pipe)
if [[ -z $SA ]]
then
   echo "--> create service account"
   oc apply -f $scriptDir/../environments/openshift-pipelines/robot-sa.yaml
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: build-robot-role-binding
subjects:
- kind: ServiceAccount
  name: build-robot
  namespace:  ${YOUR_PROJECT_NAME}-pipe
roleRef:
  kind: ClusterRole 
  name: builder
  apiGroup: rbac.authorization.k8s.io
EOF
else
   echo "--> service account exits"
fi

echo "Define pipelines"
PIPELINE_NAME=$(oc get pipeline -n ${YOUR_PROJECT_NAME}-pipe |grep build-quarkus-app)
if [[ -z $PIPELINE_NAME ]]
then
   echo "--> create pipeline"
   oc apply -f $scriptDir/../environments/openshift-pipelines/pipeline.yaml
else
   echo "--> pipelines exit"
fi

if [[ -z $(oc get tasks| grep maven) ]]
then
 oc  apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/maven/0.2/maven.yaml
fi

