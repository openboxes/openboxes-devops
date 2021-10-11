# Open Boxes

A package that installs and starts up an instance of OpenBoxes app in the Instant OpenHIE context.

## Getting Started

### Running inside Instant OpenHIE repository


https://openhie.github.io/instant/docs/how-to/creating-packages/#how-to-execute-your-new-package

**Note: Git clone the Instant OpenHIE repository and copy the OB package directory inside it.**

To start up the service

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


### Running standalone Instant OpenHIE deploy script

Latest documentation lives here: https://openhie.github.io/instant/docs/how-to/creating-packages/#docker-or-kubernetes-without-the-instant-openhie-repo

Download the *deploy* script to the Open Boxes package directory
```bash
wget https://raw.githubusercontent.com/openhie/instant/master/deploy.sh`
```

To startup the service
```bash
./deploy.sh init -t docker ob -c="."`
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

## Accessing the service

It will take a minute or two to run the db migrations during the init. Afterwards, to access Open Boxes:

### In Docker

* URL - `http://localhost:8083/openboxes`

## Browsing logs

### In Docker
```bash
docker logs openboxes-app -f
```
