# Real time inventory with kafka labs


## Pre-requisites

This project has only gitops files and scripts to run the solution locally or to deploy on OpenShift. 



## Lab 2: Deploy to an OpenShift Cluster

### Deploy environment

#### Tekton Pipeline

We will start by deploying Tekton and custom pipeline. First verify the environment setting in the `./scripts/env-amq-streams.sh` file.

We can use a unique script to create a project with `-pipe` suffix, deploy Tekton operator if not yet set, and a builder service account, all this with the following command.

```sh
./scripts/deployPipelineEnv.sh
```

#### Nexus repository

```sh
/scripts/deployNexus.sh
```

Get external URL to access Nexus: ``



