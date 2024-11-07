# Kind Cluster Setup Script

## Purpose

This script is designed to automate the setup of a Kubernetes cluster using [kind](https://kind.sigs.k8s.io/). It supports the creation of a multi-node cluster with configurable worker nodes and installs Calico and MetalLB for networking.

## Pre-requisites

Ensure that you have the following dependencies installed on your system:

- [Docker](https://www.docker.com/get-started): Required to run kind clusters.
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation): Kubernetes IN Docker - a tool for running local Kubernetes clusters using Docker container nodes.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): The Kubernetes command-line tool.
- [fzf](https://github.com/junegunn/fzf): A command-line fuzzy finder for interactive cluster selection.
- [docker-mac-net-connect](https://github.com/chipmk/docker-mac-net-connect)
- colima
- MetalLB https://github.com/metallb/metallb/releases

steps install docker,docker-mac-net-connect,colima,kind

## todo
kube-proxy
dns (coredns)
promeheus
grafana

## docker-mac-net-connect
### install
```bash
# Install via Homebrew
brew install chipmk/tap/docker-mac-net-connect

# Run the service and register it to launch at boot
sudo brew services start chipmk/tap/docker-mac-net-connect
```
### uninstall
```bash
sudo brew services stop chipmk/tap/docker-mac-net-connect
brew uninstall chipmk/tap/docker-mac-net-connect
```
```markdown
brew uninstall chipmk/tap/docker-mac-net-connect

Uninstalling /opt/homebrew/Cellar/docker-mac-net-connect/v0.1.2... (18 files, 9.5MB)
Error: Could not remove docker-mac-net-connect keg! Do so manually:
  sudo rm -rf /opt/homebrew/Cellar/docker-mac-net-connect/v0.1.2
```
```bash
sudo rm -rf /opt/homebrew/Cellar/docker-mac-net-connect/v0.1.2
```


## colima
### install
```bash
brew install colima
colima start --network-address
```
### uninstall
```bash
colima stop
colima delete
brew uninstall colima
```


## Usage

1. **Clone the Repository** (if applicable):
   \`\`\`bash
   git clone git@github.com:itunified-buecheleb/k8s.git
   cd <repository-directory>
   \`\`\`

2. **Make the Script Executable**:
   \`\`\`bash
   chmod +x create.sh
   \`\`\`

3. **Run the Script**:
   \`\`\`bash
   ./create.sh --worker-count <number_of_workers> [--force]
   \`\`\`

   - \`--worker-count <number_of_workers>\`: Specify the number of worker nodes you want in your cluster. Default is 2.
   - \`--force\`: (Optional) If provided, any existing clusters will be deleted before creating a new cluster.

### Example

To create a cluster with 3 worker nodes:
\`\`\`bash
./create.sh --worker-count 3
\`\`\`

To create a cluster with 2 worker nodes and force delete any existing clusters:
\`\`\`bash
./create.sh --worker-count 2 --force
\`\`\`

### Post-Creation Steps

After running the script, you can SSH into the nodes using the provided commands. For example:
\`\`\`bash
ssh -i ~/.ssh/kind root@localhost -p 2222
ssh -i ~/.ssh/kind root@localhost -p 2223
\`\`\`

### Updating \`/etc/hosts\`

The script will prompt you to update your \`/etc/hosts\` file to add entries for the cluster nodes. This is necessary for DNS resolution within the cluster.

### Configuring SSH

Ensure you run the \`configure_ssh.sh\` script to set up SSH access to the nodes.
\`\`\`bash
./configure_ssh.sh
\`\`\`

## Installed Components

The script installs and configures the following components:

- **Calico**: A networking and network policy provider. It ensures network connectivity between pods and enforces network policies.
- **MetalLB**: A load-balancer implementation for bare metal Kubernetes clusters, providing external IPs to services.
- **CoreDNS**: A flexible, extensible DNS server that can serve as the DNS server for the cluster.

### Setting Up Routing on macOS

#### install colima
```bash
brew install colima
colima start --network-address
colima ssh -- sudo apt update
colima ssh -- sudo apt install net-tools
colima list
```
**when no ip address is getting exposed**
```bash
colima stop
sudo rm -rf /etc/sudoers.d/colima /opt/colima
colima start --network-address
```

#### setup routing
Then, we need to set up a route on the Mac to send traffic to the VM.


To access the Kubernetes services running in your \`kind\` cluster from your host machine, you need to set up routing:

1. **Find the Docker Network Gateway IP**:

   \`\`\`sh
   docker network inspect -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}' kind
   \`\`\`

   Assuming the output is \`172.18.0.1\`, this is your Docker network gateway IP.

2. **Add Route to Your Host**:

   \`\`\`sh
   sudo route -n add 10.96.0.0/12 172.18.0.1
   \`\`\`

3. **Verify the Route**:

   \`\`\`sh
   netstat -nr | grep 10.96
   \`\`\`

   You should see an entry that routes traffic for \`10.96.0.0/12\` through \`172.18.0.1\`.

## Note

This script is intended for local development and testing purposes only. It is not recommended for production use.

## docker 

```bash
sudo vi /etc/docker/daemon.json
{
  "iptables": false,
  "ip-forward": true
}

```
