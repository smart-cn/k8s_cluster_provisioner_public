#!/bin/bash

sudo apt update
sudo apt upgrade -y
sudo snap install microk8s --classic --channel=1.27
sudo microk8s status --wait-ready
sudo usermod -a -G microk8s ubuntu
sudo -u ubuntu newgrp microk8s
echo "alias kubectl='microk8s kubectl'" | sudo tee -a /etc/bash.bashrc
microk8s enable rbac
microk8s enable hostpath-storage
microk8s enable ingress
microk8s enable dashboard
microk8s enable metrics-server
microk8s enable prometheus
microk8s kubectl create ns kubernetes-dashboard
sudo mkdir -p /home/ubuntu/secrets
cat << EOF > /tmp/dashboard-sa.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
microk8s kubectl apply -f /tmp/dashboard-sa.yml
cat << EOF > /tmp/dashboard-crb.yml 
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
microk8s kubectl apply -f /tmp/dashboard-crb.yml
cat << EOF > /tmp/dashboard-secret.yml
apiVersion: v1
kind: Secret
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "admin-user"   
type: kubernetes.io/service-account-token 
EOF
microk8s kubectl apply -f /tmp/dashboard-secret.yml
microk8s kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d > /home/ubuntu/secrets/dashboard_token.txt
sudo chown ubuntu:ubuntu /home/ubuntu/secrets
sudo chown ubuntu:ubuntu /home/ubuntu/secrets/*