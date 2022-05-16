#!/bin/sh

helm -n k8s-archiver upgrade k8s-archiver --install ./ -f values.yaml
