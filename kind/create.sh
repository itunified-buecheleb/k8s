#!/bin/bash

# Set default values
WORKER_COUNT=2
FORCE=false
CLUSTER_NAME="k8s.local"
KIND_CONFIG="kind-config.yaml"
METALLB_CONFIG_IP_POOL="metallb-config.ip-pool.yaml"
METALLB_CONFIG_L2ADD="metallb-config.l2advertisement.yaml"
CALICO_MANIFEST="https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml"
METALLB_MANIFEST="https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --worker-count) WORKER_COUNT="$2"; shift ;;
        --force) FORCE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Function to display an error message and exit
function error_exit {
    echo "$1"
    exit 1
}

# Function to free up the specified port
function free_port {
    port=$1
    pid=$(lsof -t -i tcp:${port})
    if [[ -n "$pid" ]]; then
        echo "Port ${port} is in use by PID $pid. Terminating..."
        kill -9 $pid || error_exit "Failed to free up port ${port}."
    fi
}

# Function to create the kind configuration file
function create_kind_config {
    cat <<EOF > $KIND_CONFIG
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 6443
        hostPort: 6443
        protocol: TCP
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
      - containerPort: 22
        hostPort: 2222
      - containerPort: 1521
        hostPort: 1521
      - containerPort: 31521
        hostPort: 31521  # Add NodePort mapping for control-plane if needed
      - containerPort: 5500
        hostPort: 5500
EOF

    for ((i=1; i<=WORKER_COUNT; i++)); do
        port=$((2222 + i))
        nodeport=$((i + 1521))
        cat <<EOF >> $KIND_CONFIG
  - role: worker
    extraPortMappings:
      - containerPort: 22
        hostPort: ${port}
      - containerPort: 31521
        hostPort: ${nodeport}
EOF
    done
}

# Function to select and delete clusters
function select_and_delete_clusters {
    existing_clusters=($(kind get clusters))
    if [ ${#existing_clusters[@]} -eq 0 ]; then
        echo "No kind clusters found."
        return
    fi

    cluster_array=()
    for i in "${!existing_clusters[@]}"; do
        if [[ "${existing_clusters[$i]}" == "$CLUSTER_NAME" ]]; then
            cluster_array+=("($((i+1))) ${existing_clusters[$i]}")
        else
            cluster_array+=("($((i+1))) ${existing_clusters[$i]}")
        fi
    done
    cluster_array+=("(0) delete none")
    cluster_array+=("(all) delete all local clusters")

    selected_ids=$(printf "%s\n" "${cluster_array[@]}" | fzf --ansi --multi --preview='echo {}' --preview-window=down:10%)

    if [[ -z "$selected_ids" ]]; then
        echo "No clusters selected. Exiting."
        exit 0
    elif [[ "$selected_ids" == *"(all)"* ]]; then
        kind delete cluster --all
    else
        for id in $(echo "$selected_ids" | grep -o '([0-9]*)' | tr -d '()'); do
            if [[ "$id" -gt 0 && "$id" -le ${#existing_clusters[@]} ]]; then
                kind delete cluster --name "${existing_clusters[$((id-1))]}"
            fi
        done
    fi
}

# Check if the kind cluster already exists
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo -e "Cluster '$CLUSTER_NAME' already exists."
    select_and_delete_clusters
fi

# Free up ports for control-plane and worker nodes
free_port 2222
free_port 1521
free_port 5500
for ((i=1; i<=WORKER_COUNT; i++)); do
    port=$((2222 + i))
    free_port ${port}
done

# Create the kind configuration file
create_kind_config

# Create the kind cluster with the specified configuration
kind create cluster --name $CLUSTER_NAME --config $KIND_CONFIG || error_exit "Failed to create cluster."

echo "Cluster '$CLUSTER_NAME' created successfully."

# Install Calico
kubectl apply -f $CALICO_MANIFEST || error_exit "Failed to apply Calico manifest."

# Wait for Calico pods to be ready
echo "Waiting for Calico pods to be ready..."
kubectl wait --for=condition=Ready pods --all --namespace=kube-system --timeout=300s || error_exit "Calico pods did not become ready in time."

echo "Calico installed successfully."

# Install MetalLB
echo "---------------------------------------------------"
echo "*********************"
echo "** Install MetalLB **"
echo "*********************"
echo "-- apply manifest"
kubectl apply -f $METALLB_MANIFEST || error_exit "Failed to apply MetalLB manifest."

# Wait until MetalLB pods are running
while [[ $(kubectl get pods -n metallb-system -o jsonpath="{.items[*].status.containerStatuses[*].ready}" | grep -c "false") -gt 0 ]]; do
  echo "Waiting for MetalLB pods to be ready..."
  sleep 5
done


# Generate a random string for the MetalLB secret
METALLB_SECRET=$(openssl rand -base64 32)

# Create the MetalLB secret
echo "-- apply secret"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: memberlist
  namespace: metallb-system
stringData:
  secretkey: "$METALLB_SECRET"
EOF

# Create MetalLB configuration  IPAddressPool
echo "-- apply IPAddressPool"
cat <<EOF > $METALLB_CONFIG_IP_POOL
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.0.240-172.18.0.250
EOF

# Create MetalLB configuration L2Advertisement
echo "-- apply L2Advertisement"
cat <<EOF > $METALLB_CONFIG_L2ADD
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF



# Apply MetalLB configuration
kubectl apply -f $METALLB_CONFIG_IP_POOL || error_exit "Failed to apply MetalLB config IPAddressPool."
kubectl apply -f $METALLB_CONFIG_L2ADD || error_exit "Failed to apply MetalLB config L2Advertisement."

echo "MetalLB installed and configured successfully."
echo "---------------------------------------------------"

# Wait for all pods to be ready
echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=Ready pods --all --namespace=kube-system --timeout=300s || error_exit "Some pods did not become ready in time."

# Function to verify MetalLB configuration
function verify_metallb {
    echo "Verifying MetalLB configuration..."
    kubectl get configmap config -n metallb-system -o yaml
    kubectl get pods -n metallb-system
    kubectl logs -n metallb-system -l app=metallb -c controller
    kubectl logs -n metallb-system -l app=metallb -c speaker
    kubectl describe svc foo-bar-service
}

verify_metallb

echo "Cluster setup completed successfully."

echo "You can now SSH into the nodes using the following commands after running configure_ssh.sh:"
echo "Node control-plane:"
echo "  ssh -i ~/.ssh/kind root@localhost -p 2222"

for ((i=1; i<=WORKER_COUNT; i++)); do
    port=$((2222 + i))
    echo "Node worker${i}:"
    echo "  ssh -i ~/.ssh/kind root@localhost -p ${port}"
done

# Function to update /etc/hosts file
function update_hosts_file {
    backup_file="/etc/hosts.backup.$(date +%s)"
    sudo cp /etc/hosts $backup_file
    echo "Backup of /etc/hosts created at $backup_file"

    entries="127.0.0.1 control-plane"
    for ((i=1; i<=WORKER_COUNT; i++)); do
        entries+=" worker${i}"
    done

    echo "The following entry will be added to /etc/hosts:"
    echo "$entries"
    read -p "Do you want to proceed with updating /etc/hosts? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        for name in control-plane $(seq -f "worker%g" 1 $WORKER_COUNT); do
            if grep -q "$name" /etc/hosts; then
                sudo sed -i.bak "/$name/c\\$entries" /etc/hosts
            else
                echo "$entries" | sudo tee -a /etc/hosts
            fi
        done
        echo "/etc/hosts updated successfully."
    else
        echo "No changes made to /etc/hosts."
    fi
}

# Update /etc/hosts file
update_hosts_file

