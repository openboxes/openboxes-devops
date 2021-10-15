#!/bin/bash

k8sMainRootFilePath=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

obServerUrl=''

cloud_setup () {
    echo "Running cloud setup..."

    obPort=$(kubectl get service openboxes-app -o=jsonpath={.spec.ports[0].port})

    while
        obHostname=$(kubectl get service openboxes-app -o=jsonpath="{.status.loadBalancer.ingress[*]['hostname', 'ip']}")
        obUrlLength=$(expr length "$obHostname")
        (( obUrlLength <= 0 ))
    do
        echo "OpenBoxes not ready. Sleep 5"
        sleep 5
    done

    obServerUrl="http://$obHostname:$obPort"
}

local_setup () {
    echo "Running local setup..."

    minikubeIP=$(kubectl config view -o=jsonpath='{.clusters[?(@.name=="minikube")].cluster.server}' | awk '{ split($0,A,/:\/*/) ; print A[2] }')
    obPort=$(kubectl get service openboxes-app -o=jsonpath={.spec.ports[0].nodePort})

    obServerUrl="http://$minikubeIP:$obPort"
}

print_server_url () {
    printf "\nOpenBoxes Server Url\n--------------------\n"$obServerUrl"/openboxes\n\n"
}

if [ "$1" == "init" ]; then

    kubectl apply -k $k8sMainRootFilePath

    envContextName=$(kubectl config get-contexts | grep '*' | awk '{print $2}')
    envContextMinikube=$(echo $envContextName | grep 'minikube')

    if [ $(expr length "$envContextMinikube") -le 0 ]; then
        cloud_setup
    else
        local_setup
    fi

    print_server_url
elif [ "$1" == "up" ]; then

    kubectl apply -k $k8sMainRootFilePath

    envContextName=$(kubectl config get-contexts | grep '*' | awk '{print $2}')
    envContextMinikube=$(echo $envContextName | grep 'minikube')

    if [ $(expr length "$envContextMinikube") -le 0 ]; then
        cloud_setup
    else
        local_setup
    fi

    print_server_url
elif [ "$1" == "down" ]; then

    kubectl delete -k $k8sMainRootFilePath

elif [ "$1" == "destroy" ]; then

    kubectl delete -k $k8sMainRootFilePath

else
    echo "Valid options are: init, up, down, or destroy"
fi
