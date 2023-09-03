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
microk8s kubectl apply -f configs/dashboard-sa.yml
microk8s kubectl apply -f configs/dashboard-crb.yml
microk8s kubectl apply -f configs/dashboard-secret.yml
sudo mkdir -p /home/ubuntu/secrets
microk8s kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d > /home/ubuntu/secrets/dashboard_token.txt
sudo chown ubuntu:ubuntu /home/ubuntu/secrets
sudo chown ubuntu:ubuntu /home/ubuntu/secrets/*