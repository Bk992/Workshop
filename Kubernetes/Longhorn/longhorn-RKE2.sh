#!/bin/bash

#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# THIS SCRIPT IS FOR RKE2, NOT K3S!
# THIS SCRIPT IS FOR RKE2, NOT K3S!
# THIS SCRIPT IS FOR RKE2, NOT K3S!

# Set the IP addresses of master1
master1=192.168.10.30

# Set the IP addresses of your Longhorn nodes
longhorn1=192.168.10.60
longhorn2=192.168.10.61
longhorn3=192.168.10.62

# User of remote machines
user=cluster

# Interface used on remotes
interface=eth0

# Set the virtual IP address (VIP)
vip=192.168.10.50

# Array of longhorn nodes
storage=($longhorn1 $longhorn2 $longhorn3)

#ssh certificate name variable
certName=id_rsa

#############################################
#            DO NOT EDIT BELOW              #
#############################################
# For testing purposes - in case time is wrong due to VM snapshots
sudo timedatectl set-ntp off
sudo timedatectl set-ntp on

# add ssh keys for all nodes
for node in "${storage[@]}"; do
  ssh-copy-id $user@$node
done

# add open-iscsi - needed for Debian and non-cloud Ubuntu
if ! command -v sudo service open-iscsi status &> /dev/null
then
    echo -e " \033[31;5mOpen-ISCSI not found, installing\033[0m"
    sudo apt install open-iscsi
else
    echo -e " \033[32;5mOpen-ISCSI already installed\033[0m"
fi

# Step 1: Add new longhorn nodes to cluster (note: label added)
# Set token variable needed for RKE2 (not required for K3S)
token=`cat token`
for newnode in "${storage[@]}"; do
  ssh -tt $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  mkdir -p /etc/rancher/rke2
  touch /etc/rancher/rke2/config.yaml
  echo "token: $token" >> /etc/rancher/rke2/config.yaml
  echo "server: https://$vip:9345" >> /etc/rancher/rke2/config.yaml
  echo "node-label:" >> /etc/rancher/rke2/config.yaml
  echo "  - longhorn=true" >> /etc/rancher/rke2/config.yaml
  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
  systemctl enable rke2-agent.service
  systemctl start rke2-agent.service
  exit
EOF
  echo -e " \033[32;5mLonghorn node joined successfully!\033[0m"
done

# Step 2: Install Longhorn (using modified Official to pin to Longhorn Nodes)
kubectl apply -f https://raw.githubusercontent.com/Bk992/Workshop/main/Kubernetes/Longhorn/longhorn.yaml
kubectl get pods \
--namespace longhorn-system \
--watch

# Step 3: Print out confirmation

kubectl get nodes
kubectl get svc -n longhorn-system

echo -e " \033[32;5mHappy Kubing! Access Longhorn through Rancher UI\033[0m"
