## Kubernetes

#### Kubernetes directory structure:
-  `base` - contains base Kuberenetes (Kustomize) configuration for Deplyoments, Services, PersistentVolumeClaim and Ingress
- `local-overlay` - extends base - contains Kustomization for local (non-managed) cluster setup
- `aks-overlay` - extends base - contains Kustomization for Azure AKS.

#### Kubernetes config structure:

-  `kustomization.yaml` - stiches all templates together. Contains secrets setup for database. Serves as parametrization (patch) layer.
-  `deployment.yaml` - contains definitions for OpenBoxes and MySQL deployment and PersistentVolumeClaim for MySQL setup
-  `service.yaml` - contains definitions for OpenBoxes and MySQL services
-  `ingress.yaml` - contains definion for ingress rule. 
- `set_ingress_controller_annotation.yaml` - contains patch to setup proper annotation for Ingress Controller in AKS

## Run on Azure AKS

#### Prerequisities:
- Azure VPC account is setup
- Azure CLI is installed and authorized with the account (use `az login`)
- `kubectl` client is installed locally (can be installed with `az aks install-cli`)

#### Instructions:

1. Create AKS cluster (https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough)
`az aks create --resource-group myResourceGroup --name myAKSCluster --node-count 1 --enable-addons monitoring --generate-ssh-keys`
1. Configure `kubectl` to connect to Kubernetes cluster. 
`az aks get-credentials --resource-group myResourceGroup --name myAKSCluster`
(MicroK8s note: You can change `kubectl` context to local again with `kubectl config use-context microk8s`)
1. Setup Ingress controller: https://docs.microsoft.com/en-us/azure/aks/ingress-basic
`helm install ingress-nginx ingress-nginx/ingress-nginx`
1. Browse to the _k8s/aks-overlay_ directory
1. Edit the _kustomization.yaml_. Change the MySQL database user and root password in the secret generator section.
1. Apply _kustomization.yaml_ with 
`kubectl apply -k .`
1. Wait for migrations to run. See progress with:
`kubectl logs -f deploy/app`
1. Find cluster ingress controller's external IP.
`kubectl get services --all-namespaces | grep ingress`
1. OpenBoxes app will be available at
`http://<CLUSTER_EXTERNAL_IP>/openboxes`

## Run Kubernetes cluster locally

#### Prerequisities:
- MicroK8s/minikube/k3d 1.22 is installed (MicroK8s on Ubuntu 18+: `sudo snap install microk8s --classic`)
- Kubernetes cluster is initiated
- Kubernetes addons for _**storage**_ and _**ingress**_ are enabled (in case of MicroK8s: `microk8s enable ingress storage`)

#### Instructions:

1. Browse to the _k8s/local-overlay_ directory.
1. Edit the `kustomization.yaml`. Change the MySQL database user and root password.
1. Run kustomization.yaml with 
`kubectl apply -k .`
1. By default OpenBoxes app will be available at _localhost/openboxes_

## Not supported yet

* changing number of replicas in OB and MySQL apps within kustomization.yaml
* load balancer setup
