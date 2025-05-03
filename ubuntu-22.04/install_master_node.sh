#!/bin/bash
set -e

K8S_VERSION="1.29.15-1.1"

# Install ntpdate and sync time
apt-get update
apt-get install -y ntpdate
timedatectl set-ntp false
ntpdate ntp.ubuntu.com
timedatectl set-ntp true
timedatectl set-timezone Europe/Warsaw
apt-get clean
rm -rf /var/lib/apt/lists/*
apt-get update

# Configure systemd-timesyncd
apt-get install -y systemd
cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=ntp.ubuntu.com
FallbackNTP=ntp.ubuntu.com
EOF
systemctl restart systemd-timesyncd
systemctl enable systemd-timesyncd

# Kernel modules
modprobe overlay
modprobe br_netfilter
tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# Sysctl params
tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# Install containerd
apt-get update
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Add Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}
apt-mark hold kubelet kubeadm kubectl

# Pre-pull images
kubeadm config images pull --kubernetes-version=${K8S_VERSION%-*}

# Init kubeadm
kubeadm init --apiserver-advertise-address=192.168.0.180 --pod-network-cidr=10.0.0.0/24 --kubernetes-version=${K8S_VERSION%-*}

# Kubeconfig for ansible user
mkdir -p /home/ansible/.kube
cp /etc/kubernetes/admin.conf /home/ansible/.kube/config
chown ansible:ansible /home/ansible/.kube/config

# Calico CNI
su - ansible -c "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml"
