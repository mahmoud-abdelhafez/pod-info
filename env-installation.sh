echo "kubectl installation"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
echo `which kubectl`

echo "Install kind k8s"

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind

echo `which kind`

echo "Install the k8s staging cluster"

cat > kind-config.yaml  <<EOF
# three node (two workers) cluster config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

kind create cluster --name staging --config kind-config.yaml


echo "Install flux gitops tool"
curl -s https://fluxcd.io/install.sh | sudo bash