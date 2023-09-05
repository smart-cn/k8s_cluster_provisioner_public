#!/bin/bash

sudo apt update
sudo apt upgrade -y
sudo snap install microk8s --classic --channel=1.27
sudo microk8s status --wait-ready
sudo usermod -a -G microk8s ubuntu
sudo -u ubuntu newgrp microk8s
echo "alias kubectl='microk8s kubectl'" | sudo tee -a /etc/bash.bashrc
echo "alias helm='microk8s helm'" | sudo tee -a /etc/bash.bashrc
microk8s enable rbac
microk8s enable hostpath-storage
microk8s enable ingress
microk8s enable metrics-server
microk8s enable prometheus
microk8s helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
microk8s helm repo update
microk8s helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --namespace=kubernetes-dashboard \
  --create-namespace \
  --wait
microk8s kubectl apply -f configs/dashboard-ingress.yml
microk8s kubectl apply -f configs/dashboard-sa.yml
microk8s kubectl apply -f configs/dashboard-crb.yml
microk8s kubectl apply -f configs/dashboard-secret.yml
sudo mkdir -p /home/ubuntu/secrets
microk8s kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d > /home/ubuntu/secrets/dashboard_token.txt
microk8s helm repo add grafana https://grafana.github.io/helm-charts
microk8s helm repo update
microk8s helm install grafana grafana/grafana \
  --namespace=grafana \
  --create-namespace \
  --set "datasources.datasources\\.yaml.apiVersion=1" \
  --set "datasources.datasources\\.yaml.datasources[0].name=Prometheus" \
  --set "datasources.datasources\\.yaml.datasources[0].type=prometheus" \
  --set "datasources.datasources\\.yaml.datasources[0].url=http://kube-prom-stack-kube-prome-prometheus.observability.svc.cluster.local:9090" \
  --set "datasources.datasources\\.yaml.datasources[0].access=proxy" \
  --set "datasources.datasources\\.yaml.datasources[0].isDefault=true" \
  --set env.GF_SERVER_ROOT_URL="http://localhost/grafana/" \
  --wait
microk8s kubectl apply -f configs/grafana-ingress.yml
microk8s kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 -d > /home/ubuntu/secrets/grafana_token.txt
sudo chown ubuntu:ubuntu /home/ubuntu/secrets
sudo chown ubuntu:ubuntu /home/ubuntu/secrets/**
wget -qO- https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar zxvf -  -C /tmp/; sudo mv /tmp/k9s /usr/local/bin