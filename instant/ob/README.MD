# Open Boxes

A package that installs and starts up an Docker/Kubernetes instance of OpenBoxes app in the Instant OpenHIE context. 

## Getting Started

### Running inside Instant OpenHIE repository

https://openhie.github.io/instant/docs/how-to/creating-packages/#how-to-execute-your-new-package

**Note: Git clone the Instant OpenHIE repository and copy the OB package directory to it.**

#### Docker-compose

To start up the service run below commands in the Instant OpenHIE directory.

```sh
yarn
yarn docker:build
yarn docker:instant init -t docker ob
```

To tear down the deployment use the opposing command:

```bash
yarn docker:instant down -t docker ob
```

To start up the service after a tear down, use the following command:

```bash
yarn docker:instant up -t docker ob
```

To completely remove all package components use the following option:

```bash
yarn docker:instant destroy -t docker ob
```

#### Kubernetes

To start up the service run below commands in the Instant OpenHIE directory.

```sh
yarn
yarn docker:build
yarn docker:instant init -t k8s ob
```

To tear down the deployment use the opposing command:

```bash
yarn docker:instant down -t k8s ob
```

To start up the service after a tear down, use the following command:

```bash
yarn docker:instant up -t k8s ob
```

To completely remove all package components use the following option:

```bash
yarn docker:instant destroy -t k8s ob
```


### Running standalone Instant OpenHIE deploy script

Latest documentation lives here: https://openhie.github.io/instant/docs/how-to/creating-packages/#docker-or-kubernetes-without-the-instant-openhie-repo

Download the *deploy* script **to the OpenBoxes package directory**
```bash
wget https://raw.githubusercontent.com/openhie/instant/master/deploy.sh
```

Make the *deploy* script executable
```bash
chmod +x deploy.sh
```

To startup the service
```bash
./deploy.sh init -t docker ob -c="."
```

To tear down the deployment use the opposing command:

```bash
./deploy.sh down -t docker ob
```

To start up the service after a tear down, use the following command:

```bash
./deploy.sh up -t docker ob
```

To remove the instant project, run the following:
```bash
./deploy.sh destroy -t docker ob
```

**You can run the standalone deploy script with the Kubernetes package by using `-t k8s` instead of `-t docker`**

## Accessing the service

It will take a minute or two to run the db migrations during the init. Afterwards, to access Open Boxes:

#### In Docker

* URL - `http://localhost:8083/openboxes`

#### In Kubernetes

Use the host ip or DNS, and the port `8083` for the cloud setup. 
If the deployment has been done to a [minikube](https://kubernetes.io/docs/setup/learning-environment/minikube/) cluster, get the external ip and port for the `openboxes-app` service by running the following command

```sh
kubectl get service openboxes-app
```

#### Credentials 
The default admin credentials for logging in are below. Change them once you log in.

* USERNAME - admin
* PASSWORD - password


## Browsing logs

#### In Docker
```bash
docker logs openboxes-app -f
```

#### In Kubernetes
```bash
kubectl logs -f deploy/openboxes-app
```

