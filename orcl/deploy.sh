#!/bin/bash

# Funktion zur Anzeige der Verwendung
usage() {
  echo "Usage: $0 [--force]"
  exit 1
}

# Überprüfe die Argumente
FORCE=false
if [ "$1" == "--force" ]; then
  FORCE=true
elif [ "$#" -gt 0 ]; then
  usage
fi

# Prompt for namespace
read -p "Bitte geben Sie den Namespace ein: " NAMESPACE

# Check if namespace exists
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  if [ "$FORCE" == true ]; then
    echo "Namespace $NAMESPACE wird gelöscht und neu erstellt."
    kubectl delete namespace "$NAMESPACE"
    kubectl create namespace "$NAMESPACE"
  else
    echo "Namespace $NAMESPACE existiert bereits."
  fi
else
  echo "Namespace $NAMESPACE existiert nicht. Erstelle Namespace $NAMESPACE."
  kubectl create namespace "$NAMESPACE"
fi

# Apply the YAML files in the specified namespace
 kubectl create secret docker-registry docker-hub-cred \
  --docker-username=$(svault --getUsername --name hub_docker_buecheleb) \
  --docker-password=$(svault --getPassword --name hub_docker_buecheleb) -n $NAMESPACE

kubectl apply -f pv.yaml --namespace="$NAMESPACE"
kubectl apply -f pvc.yaml --namespace="$NAMESPACE"
kubectl apply -f deployment.yaml --namespace="$NAMESPACE"
kubectl apply -f service.yaml --namespace="$NAMESPACE"

echo "Deployment abgeschlossen in Namespace $NAMESPACE."

