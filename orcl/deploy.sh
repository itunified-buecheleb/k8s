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
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=$(cd ~/github/itunified-buecheleb/spass/ && node src/main --getUsername --name hub_docker_buecheleb) \
  --docker-password=$(cd ~/github/itunified-buecheleb/spass/ && node src/main --getPassword --name hub_docker_buecheleb) -n $NAMESPACE

sleep 5

kubectl apply -f pv.yaml --namespace="$NAMESPACE"
kubectl apply -f pvc.yaml --namespace="$NAMESPACE"
kubectl apply -f deployment.yaml --namespace="$NAMESPACE"
kubectl apply -f service.yaml --namespace="$NAMESPACE"

# Check the status of the Oracle database pod
#kubectl wait --for=condition=Ready pod -l app=oracle-database -n orcl --timeout=300s

# Verify if the Oracle database pod is ready
if [ $? -eq 0 ]; then
    echo "Oracle database pod is ready."
else
    echo "Oracle database pod is not ready. Check the logs for more details."
    exit 1
fi

echo "Deployment abgeschlossen in Namespace $NAMESPACE."

