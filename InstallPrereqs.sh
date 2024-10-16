#!/bin/bash

echo "Installing Docker"

# Remove any old versions
apt update
apt remove -y docker docker-engine docker.io containerd runc docker-cli docker-openrc docker-compose

# Install dependencies
apt install --no-install-recommends -y apt-transport-https ca-certificates curl gnupg2 jq openssl
apt upgrade -y

# Remove any old Docker GPG keys
rm -f /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker's official GPG key
mkdir -p /usr/share/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

# Update and install Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Add the current user to the docker group
usermod -aG docker $USER

# Adjust the docker group ID to match across WSL and Windows
groupmod -g 36257 docker

# Set up the Docker daemon
DOCKER_DIR=/mnt/wsl/shared-docker
mkdir -pm o=,ug=rwx "$DOCKER_DIR"
chgrp docker "$DOCKER_DIR"

mkdir -p /etc/docker/

tee /etc/docker/daemon.json <<EOF
{
  "hosts": ["unix:///mnt/wsl/shared-docker/docker.sock"]
}
EOF

tee -a ~/.bashrc <<'EOF'
export DOCKER_HOST="unix:///mnt/wsl/shared-docker/docker.sock"
if [ ! -S "/mnt/wsl/shared-docker/docker.sock" ]; then
    mkdir -pm o=,ug=rwx /mnt/wsl/shared-docker
    chgrp docker /mnt/wsl/shared-docker
fi
if [ ! "$(pgrep dockerd)" ]; then
    nohup dockerd < /dev/null > /mnt/wsl/shared-docker/dockerd.log 2>&1 &
fi
EOF

# Install .NET Core (Optional)
echo "Installing .NET Core"
wget https://dot.net/v1/dotnet-install.sh -O - | bash /dev/stdin --channel LTS

tee -a ~/.bashrc <<'EOF'
export PATH=$PATH:/root/.dotnet
EOF

# Install kubectl if needed
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl"
  apt update
  apt install -y apt-transport-https ca-certificates curl

  # Remove old Kubernetes GPG key
  rm -f /etc/apt/keyrings/kubernetes-archive-keyring.gpg

  # Add Kubernetes GPG key
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

  # Add Kubernetes repository
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

  apt update
  apt install -y kubectl
fi

# Install k3d if needed
if ! command -v k3d &> /dev/null; then
  echo "Installing k3d"
  apt update
  wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
fi

apt update -y
apt upgrade -y

echo "Installation complete."
