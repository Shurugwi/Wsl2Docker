#!/bin/bash

echo -e "[network]\ngenerateResolvConf = false" | tee -a /etc/wsl.conf
unlink /etc/resolv.conf
echo nameserver 1.1.1.1 | tee /etc/resolv.conf
echo nameserver 8.8.8.8 | tee /etc/resolv.conf

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

echo nameserver 8.8.8.8 | tee /etc/resolv.conf

EOF

echo "Installation complete."
