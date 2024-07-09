#!/bin/bash

# Name of the cluster
CLUSTER_NAME="kind"

# Check if the kind cluster already exists
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME already exists. Deleting and recreating..."
    kind delete cluster --name $CLUSTER_NAME
fi

# Define the configuration file
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 1521
    hostPort: 31521
    protocol: TCP
  - containerPort: 5500
    hostPort: 35500
    protocol: TCP
EOF

# Create the kind cluster with the specified configuration
kind create cluster --name $CLUSTER_NAME --config kind-config.yaml

# Verify if the cluster is created successfully
if [ $? -eq 0 ]; then
    echo "Cluster $CLUSTER_NAME created successfully with port forwarding."
else
    echo "Failed to create cluster $CLUSTER_NAME."
    exit 1
fi

echo "Setup completed successfully."

