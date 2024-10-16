#!/bin/bash

echo "Installing Docker"

# Update package lists and remove any old Docker packages
apt update
apt remove -y docker docker-engine docker.io containerd runc docker-cli docker-openrc docker-compose

# Install prerequisites
apt install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg2 jq openssl

# Upgrade existing packages
apt upgrade -y

# Set up the Docker repository
mkdir -p /usr/share/keyrings

# Add Docker's official GPG key to the keyring
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Use 'jammy' (Ubuntu 22.04) for the Docker repository since 'noble' is not yet supported
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker.list

# Update package lists to include the new Docker repository
apt update

# Install Docker packages
apt install -y docker-ce docker-ce-cli containerd.io

# Add the current user to the 'docker' group
usermod -aG docker $USER
groupmod -g 36257 docker

# Set up Docker directories for WSL integration
DOCKER_DIR=/mnt/wsl/shared-docker
mkdir -pm o=,ug=rwx "$DOCKER_DIR"
chgrp docker "$DOCKER_DIR"

# Create Docker daemon configuration
mkdir -p /etc/docker/
tee /etc/docker/daemon.json <<EOF
{
  "hosts": ["unix:///mnt/wsl/shared-docker/docker.sock"]
}
EOF

# Update .bashrc to configure Docker environment variables and start the Docker daemon if not running
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

# Optional: Install .NET Core (Comment out if not needed)
# echo "Installing .NET Core"
# wget https://dot.net/v1/dotnet-install.sh -O - | bash /dev/stdin --channel LTS
# tee -a ~/.bashrc <<EOF
# export PATH=\$PATH:/root/.dotnet
# EOF

# Install kubectl if not already installed
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl"
  apt update
  apt install -y apt-transport-https ca-certificates curl

  # Add Kubernetes GPG key to the keyring
  curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

  # Use 'kubernetes-xenial' for the Kubernetes repository (official method)
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

  # Update package lists and install kubectl
  apt update
  apt install -y kubectl
fi

# Install k3d if not already installed
if ! command -v k3d &> /dev/null; then
  echo "Installing k3d"
  apt update
  wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
fi

# Final package updates and upgrades
apt update -y
apt upgrade -y

echo "Installation complete."
