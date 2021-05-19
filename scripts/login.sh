#!/bin/bash

############
### MAIN ###
############

function validateLogin {
  # Check the argument is what we expect
  if [[ $# -eq 1 ]];then
    if [[ "$1" == "--skip-login" ]]; then
      echo "Checking if you are logged into OpenShift..."
      oc whoami
      if [[ $? -gt 0 ]]; then
        echo "[ERROR] - An error occurred while checking if you are logged into OpenShift"
        exit 1
      fi
      echo "OK"
      SKIP_LOGIN="true"
    else
      echo "Usage: `basename "$0"` [--skip-login]"
      exit 1
    fi
  fi          

  # Log in if we need to
if [ -z $SKIP_LOGIN ]; then
  oc login -u ${OCP_ADMIN_USER} -p ${OCP_ADMIN_PASSWORD}
  if [[ $? -gt 0 ]]; then
    echo "[ERROR] - An error occurred while logging into OpenShift"
    exit 1
  fi
fi

}


