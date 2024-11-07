#!/bin/bash

# Function to get the CoreDNS IP
get_coredns_ip() {
    kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}'
}

# Function to update DNS for macOS
update_dns_macos() {
    local coredns_ip=$1
    echo "Updating DNS for macOS with CoreDNS IP: $coredns_ip"

    # Backup existing DNS settings
    local timestamp=$(date +%Y%m%d%H%M%S)
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$timestamp

    # Check if the CoreDNS IP and DNS domain are already present
    if ! grep -q "nameserver $coredns_ip" /etc/resolv.conf; then
        # Append the CoreDNS IP to /etc/resolv.conf
        echo "nameserver $coredns_ip # __kind_k8s__" | sudo tee -a /etc/resolv.conf
    fi

    if ! grep -q "search svc.cluster.local" /etc/resolv.conf; then
        # Append the DNS domain to /etc/resolv.conf
        echo "search svc.cluster.local # __kind_k8s__" | sudo tee -a /etc/resolv.conf
    fi

    # Clean up any duplicate entries
    sudo sed -i '' '/__kind_k8s__/!b;n;N;/\n.*nameserver/!P;D' /etc/resolv.conf

    # Verify the DNS settings
    scutil --dns | grep 'nameserver\[[0-9]*\]'
}

# Function to update DNS for Linux
update_dns_linux() {
    local coredns_ip=$1
    echo "Updating DNS for Linux with CoreDNS IP: $coredns_ip"

    # Backup existing DNS settings
    local timestamp=$(date +%Y%m%d%H%M%S)
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$timestamp

    # Check if the CoreDNS IP and DNS domain are already present
    if ! grep -q "nameserver $coredns_ip" /etc/resolv.conf; then
        # Append the CoreDNS IP to /etc/resolv.conf
        echo "nameserver $coredns_ip # __kind_k8s__" | sudo tee -a /etc/resolv.conf
    fi

    if ! grep -q "search svc.cluster.local" /etc/resolv.conf; then
        # Append the DNS domain to /etc/resolv.conf
        echo "search svc.cluster.local # __kind_k8s__" | sudo tee -a /etc/resolv.conf
    fi

    # Clean up any duplicate entries
    sudo sed -i '/__kind_k8s__/!b;n;N;/\n.*nameserver/!P;D' /etc/resolv.conf

    # Verify the DNS settings
    grep 'nameserver\|search' /etc/resolv.conf
}

# Main script logic
coredns_ip=$(get_coredns_ip)
if [ -z "$coredns_ip" ]; then
    echo "Failed to retrieve CoreDNS IP. Ensure your cluster is running and CoreDNS is deployed."
    exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    update_dns_macos $coredns_ip
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    update_dns_linux $coredns_ip
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

# Verify CoreDNS setup
echo "Verifying DNS setup with CoreDNS IP: $coredns_ip"
nslookup kubernetes.default.svc.cluster.local $coredns_ip

