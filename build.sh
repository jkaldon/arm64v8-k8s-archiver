#!/bin/sh
set -x

DOCKER_TAG=alpine3.15-1

docker build --progress plain -t "jkaldon/arm64v8-k8s-archiver:${DOCKER_TAG}" .

docker push "jkaldon/arm64v8-k8s-archiver:${DOCKER_TAG}"

