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
EOF
}

function waitUntilOperatorReady() {
  echo "Waiting for strimzi-kafka-operator operator to be deployed..."
  counter=0
  desired_state="AtLatestKnown"
  until [[ ("$(oc get -n openshift-operators subscription $1 -o jsonpath="{.status.state}")" == "${desired_state}") || ( ${counter} == 60 ) ]]
  do
    ((counter++))
    echo -n "..."
    sleep 5
  done
  if [[ ${counter} == 60 ]]
  then
    echo
    echo "[ERROR] - Timeout occurred while deploying the $1"
    exit 1
  else
    echo "Done"
  fi
}