#!/usr/bin/env bash
set -e

if [ -z "$K8S_ARCHIVER_REPO" ]; then
  printf "ERROR: Environment value K8S_ARCHIVER_REPO not set.\n"
  exit 3
fi

if [ -z "$K8S_ARCHIVER_EMAIL_ADDRESS" ]; then
  printf "ERROR: Environment value K8S_ARCHIVER_EMAIL_ADDRESS not set.\n"
  exit 4
fi

if [ -z "$K8S_ARCHIVER_EMAIL_NAME" ]; then
  printf "ERROR: Environment value K8S_ARCHIVER_EMAIL_NAME not set.\n"
  exit 5
fi

if [ -z "$K8S_ARCHIVER_PROFILES" ]; then
  printf "ERROR: Environment value K8S_ARCHIVER_PROFILES not set.\n"
  exit 6
fi


stripFieldsThatProduceLotsOfNoise() {
  local FILE=$1
  printf "Stripping noisy fields from yml file \"$FILE\"...\n"

  set -x
  yq eval 'del(.items.[].metadata.annotations."autoscaling.alpha.kubernetes.io/conditions")' -i $FILE
  yq eval 'del(.items.[].metadata.annotations."autoscaling.alpha.kubernetes.io/current-metrics")' -i $FILE
  yq eval 'del(.items.[].metadata.annotations."control-plane.alpha.kubernetes.io/leader")' -i $FILE
  yq eval 'del(.items.[].metadata.resourceVersion)' -i $FILE
  yq eval 'del(.items.[].metadata.managedFields)' -i $FILE
  yq eval 'del(.items.[].status.conditions)' -i $FILE
  set +x

  printf "...stripping completed.\n"
}

exportK8sContent() {
  local CURRENT_KUBE_CONTEXT=$1
  local RESOURCE_KIND=
  local RESOURCE_NAMESPACE=
  local RESOURCE_NAME=
  local DESTINATION_FILE=
  
  local WORK_PATH=$(mktemp -d)
  pushd "$WORK_PATH"
  
  printf "Exporting from context \"$CURRENT_KUBE_CONTEXT\"...\n"
  kubectl --context $CURRENT_KUBE_CONTEXT get -A $K8S_ARCHIVER_RESOURCES -o yml > exported.yml
  
  # Strip noisy fields.
  stripFieldsThatProduceLotsOfNoise exported.yml

  printf "Breaking exported yml to files...\n"
  yq eval '.items.[]' exported.yml > resource.yml
  rm exported.yml
  csplit -s -z -f resource- resource.yml '/^apiVersion:/' '{*}'
  rm resource.yml
  printf "...finished.\n"
 
  local FILE=
  printf "Renaming resource files to format \"<kind>_<namespace>_<name>.yml\"...\n"
  for FILE in resource-*; do
    RESOURCE_NAMESPACE=$(yq eval '.metadata.namespace // "CLUSTER"' $FILE)
    RESOURCE_KIND=$(yq eval '.kind // "MISSING"' $FILE)
    RESOURCE_NAME=$(yq eval '.metadata.name // "MISSING"' $FILE)
  
    DESTINATION_FILE=$(printf "${RESOURCE_KIND:-MISSING}_${RESOURCE_NAMESPACE:-CLUSTER}_${RESOURCE_NAME:-MISSING}" | tr : -")

    if [ -f "$DESTINATION_FILE" ]; then
      printf "WARNING: File should not exist: \"$DESTINATION_FILE\"\n"
      DESTINATION_FILE="${DESTINATION_FILE}.conflict_$(date -u +%H%M%S%N)"
    fi

    DESTINATION_FILE="${DESTINATION_FILE}.yml"
    mv "$FILE" "$DESTINATION_FILE"
    printf "."
  done
  
  printf "...finished.\n"
  popd
  
  rm -f "$CURRENT_KUBE_CONTEXT"/*
  cp "$WORK_PATH"/* "$CURRENT_KUBE_CONTEXT"/
  
  if [ "`git status --porcelain`" ]; then
    git add "$CURRENT_KUBE_CONTEXT"
    git commit -m "\"$CURRENT_KUBE_CONTEXT\" context changes"
    git push
  else
    printf "Nothing changed.  Skipping commit.\n"
  fi
}
  
git clone "$K8S_ARCHIVER_REPO" archive-repo
cd archive-repo

git config --local user.email "$K8S_ARCHIVER_EMAIL_ADDRESS"
git config --local user.name "$K8S_ARCHIVER_EMAIL_NAME"


for PROFILE in "$K8S_ARCHIVER_PROFILES"; do
  if [ -d "$PROFILE" ]; then
    exportK8sContent "$PROFILE"
  else
    printf "ERROR: Could not find \"$PROFILE\" in \"$(pwd)\".  Skipping...\n"
    PROFILE_NOT_FOUND=1
  fi
done

if [ "$PROFILE_NOT_FOUND" = "1" ]; then
  exit 125
fi
