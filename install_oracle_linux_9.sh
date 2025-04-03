
####################
## Firewall rules ##
####################

# Keep the firewall enabled and open only the necessary ports in accordance with the 
# official docs. We have a set of rules for the Control Planes nodes.

sudo firewall-cmd --set-default-zone=internal
sudo firewall-cmd --permanent \
  --add-port=6443/tcp \
  --add-port=2379-2380/tcp \
  --add-port=10250/tcp \
  --add-port=10259/tcp \
  --add-port=10257/tcp 
sudo firewall-cmd --reload

# Modprobe
sudo cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo systemctl restart systemd-modules-load.service

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
user.max_pid_namespaces             = 1048576
user.max_user_namespaces            = 1048576
EOF

sudo sysctl --system



######################
## Installing CRI-O ##
######################

# Define the Kubernetes version and used CRI-O stream

KUBERNETES_VERSION=v1.32
CRIO_VERSION=v1.32


# Add the Kubernetes repository

sudo cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF


# Add the CRI-O repository

sudo cat <<EOF | sudo tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOF


# Install package dependencies from the official repositories
sudo dnf install -y container-selinux

# Install the packages
sudo dnf install -y cri-o kubelet kubeadm kubectl

# Start CRI-O
sudo systemctl start crio.service

# Bootstrap a cluster
sudo swapoff -a
sudo modprobe br_netfilter
sudo sysctl -w net.ipv4.ip_forward=1


cat <<CONFIG > kubeadmin-config
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: $HOSTNAME
  criSocket: "unix:///var/run/crio/crio.sock"
  imagePullPolicy: "IfNotPresent"
  kubeletExtraArgs: 
    cgroup-driver: "systemd"
    resolv-conf: "/run/systemd/resolve/resolv.conf"
    max-pods: "4096"
    max-open-files: "20000000"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "$KUBERNETES_VERSION"
networking:
  podSubnet: "10.32.0.0/16"
  serviceSubnet: "172.16.16.0/22"
controllerManager:
  extraArgs:
    node-cidr-mask-size: "20"
    allocate-node-cidrs: "true"
---
CONFIG



sudo kubeadm init --skip-token-print=true --config=kubeadmin-config.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


kubectl create -f https://github.com/antrea-io/antrea/releases/download/v1.14.0/antrea.yml
