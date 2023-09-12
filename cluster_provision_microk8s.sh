#!/bin/bash

sudo apt update
sudo apt upgrade -y
sudo snap install microk8s --classic --channel=1.27
sudo microk8s status --wait-ready
sudo patch /var/snap/microk8s/current/certs/csr.conf.template < /tmp/microk8s_custom_domain.patch
sudo microk8s refresh-certs --cert server.crt
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
  -f configs/grafana-values.yml \
  --wait
microk8s kubectl apply -f configs/grafana-ingress.yml
microk8s kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 -d > /home/ubuntu/secrets/grafana_token.txt
mkdir .kube
URL=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
while true; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://${URL}:80/grafana/api/health)
    if [ "$response" == "200" ]; then
        echo "Grafana is ready!"
        break
    else
        echo "Waiting for Grafana..."
        sleep 5
    fi
done
grafana_secret=$(cat /home/ubuntu/secrets/grafana_token.txt)
for i in {1..10}; do
    sleep 2
    echo "Attempt ${i} of Grafana dashboard parameters setting"
    curl -X POST -f -H 'Content-Type: application/json' -d "{\"user\":\"admin\",\"password\":\"${grafana_secret}\"}" -c /tmp/grafana-jar.txt "http://${URL}/grafana/login" || continue
    dash_id=$(curl -sb /tmp/grafana-jar.txt "http://${URL}/grafana/api/search?mode=tree" | grep -Po '"id":(\d+)' | awk -F ':' '{print $2}')
    [ "${dash_id}" = "" ] && continue
    curl -X POST -f -b /tmp/grafana-jar.txt "http://${URL}/grafana/api/user/stars/dashboard/${dash_id}" || continue
    curl -X PUT -f -H 'Content-Type: application/json' -b /tmp/grafana-jar.txt -d "{\"homeDashboardId\":${dash_id}}" "http://$URL/grafana/api/org/preferences" && break || continue
done
mkdir  /home/ubuntu/.kube
microk8s config -l > /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/*
sudo chown ubuntu:ubuntu /home/ubuntu/secrets
sudo chown ubuntu:ubuntu /home/ubuntu/secrets/*
wget -qO- https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar zxvf -  -C /tmp/; sudo mv /tmp/k9s /usr/local/bin