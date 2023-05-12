#!/bin/bash

# echo -e "[network]\ngenerateResolvConf = false" | tee -a /etc/wsl.conf
# unlink /etc/resolv.conf
# echo nameserver 1.1.1.1 | tee /etc/resolv.conf
# echo nameserver 8.8.8.8 | tee /etc/resolv.conf

echo "Installing Docker"

apt update
apt remove docker docker-engine docker.io containerd runc docker-cli docker-openrc docker-compose
apt install --no-install-recommends apt-transport-https ca-certificates curl gnupg2 -y
apt upgrade -y

source /etc/os-release
curl -fsSL https://download.docker.com/linux/${ID}/gpg | apt-key add -

echo "deb [arch=amd64] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list
apt update

apt install docker-ce docker-ce-cli containerd.io -y
usermod -aG docker $USER
groupmod -g 36257 docker

DOCKER_DIR=/mnt/wsl/shared-docker
mkdir -pm o=,ug=rwx "$DOCKER_DIR"
chgrp docker "$DOCKER_DIR"

mkdir -p /etc/docker/

tee -a /etc/docker/daemon.json <<EOF
{
  "hosts": ["unix:///mnt/wsl/shared-docker/docker.sock"]
}
EOF

tee -a ~/.bashrc <<EOF
export DOCKER_HOST="unix:///mnt/wsl/shared-docker/docker.sock"
if [ ! -S "/mnt/wsl/shared-docker/docker.sock" ]; then
    mkdir -pm o=,ug=rwx /mnt/wsl/shared-docker
    chgrp docker /mnt/wsl/shared-docker
fi
if [ ! "\$(pgrep dockerd)" ]; then
    nohup dockerd < /dev/null > /mnt/wsl/shared-docker/dockerd.log 2>&1 &
fi

EOF

# <OPTIONAL>
# #Powershell and .Net is optional
# echo "Installing Powershell"
# wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
# dpkg -i /tmp/packages-microsoft-prod.deb
# apt update -y
# apt install powershell -y
# rm -rf /tmp/packages-microsoft-prod.deb

# #TODO: Better way to install .NET Core?
# echo "Installing .NET Core"
# wget https://dot.net/v1/dotnet-install.sh -O - | bash /dev/stdin --channel LTS

# tee -a ~/.bashrc <<EOF
# export PATH=\$PATH:/root/.dotnet
# EOF
# </OPTIONAL>

# Install kubectl if needed
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl"
  apt update
  apt install -y apt-transport-https ca-certificates curl
  curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
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
