#!/bin/sh
# Script to create K8s cluster on Photon OS VM's
# Needs master and worker VM 
# Run as root

# Usage: bash <(curl -s https://raw.githubusercontent.com/coyte/photon-k8s/main/photon-k8s-install.sh <master/worker>



# Script needs env to be set
# $ROOTPASSWORD
# $IPADDRESS (in CIDR notation 5.6.7.8/24)
# $SUBNET
# $GATEWAY
# $DNS
# $SEARCHDOMAIN
# $CLUSTERIPRANGE (=172.160.0.0/16)
# $AUTOTHIZEKEYSSERVER (user@server)
# $AUTOTHIZEKEYSPASS

# Source: http://kubernetes.io/docs/getting-started-guides/kubeadm

# Exit on error
set -e

# Test env variables
if [[ -z "${IPADDRESS}" ]]; then Exit



source /etc/lsb-release
if [ "$DISTRIB_RELEASE" != "4.0" ]; then
    echo "################################# "
    echo "############ WARNING ############ "
    echo "################################# "
    echo
    echo "This script was made for  Photon OS 4.0!"
    echo "You're using: ${DISTRIB_DESCRIPTION}"
    echo "Better ABORT with Ctrl+C. Or press any key to continue the install"
    read
fi

# SYSTEM prep

# Set network
rm /etc/systemd/network/*
cat <<EOF | tee /etc/systemd/network/static.network
[Match]
Name=eth0
[Network]
Address=$IPADDRESS
Gateway=$GATEWAY
DNS=$DNS
Domains=$SEARCHDOMAIN
EOF



KUBE_VERSION=1.23.6

### setup terminal
tdnf update -y
tdnf install -y  binutils sshpass
echo 'colorscheme ron' >> ~/.vimrc
echo 'set tabstop=2' >> ~/.vimrc
echo 'set shiftwidth=2' >> ~/.vimrc
echo 'set expandtab' >> ~/.vimrc
echo 'alias ll=ls -al' >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
echo 'alias ll=ls -al' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc

#source
source ~/.bashrc

# copy authrorized-keys
sshpass -p $AUTOTHIZEKEYSPASS scp -r $AUTOTHIZEKEYSSERVER:~/.ssh/authorized-keys ~/.ssh/
chown root:root ~/.ssh/authorized-keys
chmod 400 ~/.ssh/authorized-keys

### disable linux swap and remove any existing swap partitions
swapoff -a
sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab

### remove packages
kubeadm reset -f || true #reset cluster or unjoin nodes
crictl rm --force $(crictl ps -a -q) || true #delete all container
tdnf -y remove docker 
tdnf -y remove containerd
tdnf -y remove cri-o
tdnf -y remove kubeadm
tdnf -y remove crictl
tdnf -y remove postman
tdnf -y remove sshpass

apt-mark unhold kubelet kubeadm kubectl kubernetes-cni || true
apt-get remove -y docker.io containerd kubelet kubeadm kubectl kubernetes-cni || true
apt-get autoremove -y
systemctl daemon-reload

