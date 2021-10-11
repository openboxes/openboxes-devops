#!/bin/bash

sleep 10

composeFilePath=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

if [ "$1" == "init" ]; then

    docker-compose -p instant -f "$composeFilePath"/docker-compose.yml up -d

elif [ "$1" == "up" ]; then

    docker-compose -p instant -f "$composeFilePath"/docker-compose.yml up -d

elif [ "$1" == "down" ]; then

    docker-compose -p instant -f "$composeFilePath"/docker-compose.yml stop

elif [ "$1" == "destroy" ]; then

    docker-compose -p instant -f "$composeFilePath"/docker-compose.yml down

    docker volume rm instant_ob-mysql-data
else
    echo "Valid options are: init, up, down, or destroy"
fi
