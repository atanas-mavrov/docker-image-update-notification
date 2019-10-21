#!/bin/bash

REPOSITORY=$1
TARGET_TAG=$2
TEMP_HEADER_FILE="/tmp/headers"
myhostname=$(hostname -s)
slackuser="${myhostname^}"

docker image inspect $REPOSITORY > /dev/null 2>&1
imageStatus=$?

if [ ! $imageStatus -eq 0 ]; then
    image_id=$(docker images | grep $REPOSITORY | awk '{ print $3 }')
    docker_inspect=$(docker image inspect $image_id)
else
    docker_inspect=$(docker image inspect $REPOSITORY)
fi

current_image=$(echo $docker_inspect | jq '.[0].RepoDigests[0]')
current_digiset=$(echo $docker_inspect | jq '.[0].Id')

if [ "$current_image" == '' ]; then
    echo "Cannot find image $REPOSITORY"
    exit
fi

OIFS=$IFS
IFS='@'
read -r -a image_array <<< "$current_image"
IFS=$OIFS
temp_id=${image_array[1]}
current_image_id=${temp_id%'"'}

# get authorization token
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$REPOSITORY:pull" | jq -r .token)

docker_registry=$(curl -s -D $TEMP_HEADER_FILE -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" https://index.docker.io/v2/$REPOSITORY/manifests/$TARGET_TAG)
docker_registry_headers=$(cat $TEMP_HEADER_FILE)

if [[ ${docker_registry_headers} != *"HTTP/1.1 200 OK"* ]]; then
    REPOSITORY=library/$REPOSITORY
    TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$REPOSITORY:pull" | jq -r .token)
    docker_registry=$(curl -s -D $TEMP_HEADER_FILE -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" https://index.docker.io/v2/$REPOSITORY/manifests/$TARGET_TAG)
fi

docker_header_digiset=$(cat $TEMP_HEADER_FILE | grep Docker-Content-Digest | awk '{print $2}' | tr -d '[:space:]' | tr '\r' ' ' | tr '/n' ' ')
docker_etag=$(cat $TEMP_HEADER_FILE | grep Etag | awk '{print $2}' | tr -d '[:space:]' | tr '\r' ' ' | tr '/n' ' ')
docker_digiset=$(echo $docker_registry | jq '.config.digest')


if [ "$docker_header_digiset" = "$current_image_id" ]; then
  exit 0
elif [ "$docker_etag" = "$current_image_id" ]; then
  exit 0
elif [ "$docker_digiset" = "$current_digiset" ]; then
  exit 0
fi

echo "There is a new image version for $REPOSITORY on $myhostname" | mail -s "UPDATING" YOUR_EMAIL

