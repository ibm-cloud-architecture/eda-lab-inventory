#!/bin/bash
scriptDir=$(dirname $0)

############
### MAIN ###
############

function createProjectAndServiceAccount {
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