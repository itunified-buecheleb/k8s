#!/bin/bash
set -x

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

# Create Docker Hub secret
kubectl create secret docker-registry docker-hub-cred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=$(cd ~/github/itunified-buecheleb/spass/ && node src/main --getUsername --name hub_docker_buecheleb) \
  --docker-password=$(cd ~/github/itunified-buecheleb/spass/ && node src/main --getPassword --name hub_docker_buecheleb) -n $NAMESPACE

# Read Database Password
PASS=$(cd ~/github/itunified-buecheleb/spass/ && node src/main --getPassword --name kind_k8s_orclcdb_sys ) 
kubectl create secret generic oracle-rdbms-credentials --namespace $NAMESPACE \
        --from-literal=ORACLE_PWD="$PASS"
sleep 5
#
# Apply Persistent Volume, Persistent Volume Claim, Deployment, Service und Ingress
kubectl apply -f ${NAMESPACE}/pv.yaml --namespace="$NAMESPACE"
kubectl apply -f ${NAMESPACE}/pvc.yaml --namespace="$NAMESPACE"
kubectl apply -f ${NAMESPACE}/configmap.yaml --namespace="$NAMESPACE"
kubectl apply -f ${NAMESPACE}/deployment.yaml --namespace="$NAMESPACE"
kubectl apply -f ${NAMESPACE}/loadbalancer.yaml --namespace="$NAMESPACE"

# Wait for the Oracle database pod to be ready
echo "Waiting for the Oracle database pod to be running..."
kubectl wait --for=condition=ready pod -l app=oracle-rdbms-${NAMESPACE} -n $NAMESPACE --timeout=600s

# Verify if the Oracle database pod is ready
if [ $? -eq 0 ]; then
    echo "Oracle database pod is running."
else
    echo "Oracle database pod is not running. Check the logs for more details."
    exit 1
fi

echo "Deployment abgeschlossen in Namespace $NAMESPACE."
