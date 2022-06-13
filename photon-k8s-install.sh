#!/bin/sh
# Script to create K8s cluster on Photon OS VM's
# Needs master and worker VM 
# Run as root

# Usage: bash <(curl -s https://raw.githubusercontent.com/coyte/photon-k8s/main/photon-k8s-install.sh <master/worker>



# Script needs env to be set
# $ROOTPASSWORD
# $IPADDRESS (in CIDR notation 5.6.7.8/24)
# $GATEWAY
# $DNS
# $SEARCHDOMAIN
# $CLUSTERIPRANGE (=172.160.0.0/16)
# $AUTHORIZEDKEYSSERVER (user@server)
# $SSHPASS

# Source: http://kubernetes.io/docs/getting-started-guides/kubeadm

echo "Exit on error"
# set -e

echo "Test env variables"
if [[ -z $ROOTPASSWORD || -z $IPADDRESS || -z $GATEWAY || -z $DNS || -z $SEARCHDOMAIN || -z $CLUSTERIPRANGE || -z $AUTHORIZEDKEYSSERVER || -z $SSHPASS ]]; then
  echo 'One or more variables are undefined'
  exit 1
fi


echo "Test for correct OS & version"
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
echo "OS Tested ok"


# SYSTEM prep
echo "setting network"
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

echo "Done setting network, restarting network"
systemctl restart systemd-networkd

KUBE_VERSION=1.23.6

echo "Configuring packages and environment,Press enter to continue"
### setup terminal
tdnf update -y
tdnf install -y  binutils sshpass
rm ~/.vimrc
rm ~/.bashrc
echo 'set tabstop=2' > ~/.vimrc
echo 'set shiftwidth=2' >> ~/.vimrc
echo 'set expandtab' >> ~/.vimrc
echo 'alias ll="ls -al"' >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc

echo "source .bashrc"
source ~/.bashrc

echo "copy authorized keys"
# copy authrorized-keys
sshpass -e scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $AUTHORIZEDKEYSSERVER:~/.ssh/authorized_keys ~/.ssh/
chown root:root ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys
echo "Done copying authorized-keys, Press enter to continue"


echo "Disable swap"
### disable linux swap and remove any existing swap partitions
swapoff -a
sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab

#Add repo's
tee /etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Clear and recreate cache
tdnf clean all 
tdnf -y makecache


echo "Remove packages"
echo "kubeadm reset"
kubeadm reset -f || true #reset cluster or unjoin nodes
echo "Clean CNI config"
rm -rf /etc/cni/net.d/*
echo "crictl rm all"
crictl rm --force $(crictl ps -a -q) || true #delete all container
echo "remove docker"
tdnf -y remove docker 
echo "remove containerd"
tdnf -y remove containerd
echo "remove cri-o"
tdnf -y remove cri-o
echo "remove kubeadm" 
tdnf -y remove kubeadm
echo "remove kubernetes-cni"
tdnf -y remove kubernetes-cni
echo "crictl"
tdnf -y remove crictl
echo "remove postman"
tdnf -y remove postman
echo "remove sshpass"
tdnf -y remove sshpass

apt-mark unhold kubelet kubeadm kubectl kubernetes-cni || true
apt-get remove -y docker.io containerd kubelet kubeadm kubectl kubernetes-cni || true
apt-get autoremove -y
systemctl daemon-reload

