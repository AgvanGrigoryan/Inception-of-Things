set -e
# Add Docker's official GPG key:
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER

sudo systemctl enable --now docker

echo "Waiting for Docker ..."
while ! sudo systemctl is-active --quiet docker; do
    sleep 2
done


curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

k3d --version

# Download the stable kubectl binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install it to your local binary path
sudo install kubectl /usr/local/bin/kubectl
rm kubectl


echo "=== Installed versions ==="
docker --version
k3d --version
kubectl version --client
echo ""
echo "NOTE: log out and back in (or run 'newgrp docker') to use docker without sudo."
