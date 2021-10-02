#!/bin/bash

echo -e "[network]\ngenerateResolvConf = false" | tee -a /etc/wsl.conf
unlink /etc/resolv.conf
echo nameserver 1.1.1.1 | tee /etc/resolv.conf

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
groupmod -g 36257 docker

DOCKER_DIR=/mnt/wsl/shared-docker
mkdir -pm o=,ug=rwx "$DOCKER_DIR"
chgrp docker "$DOCKER_DIR"

tee -a ~/.bashrc <<EOF
DOCKER_DISTRO="LocalDockerHost"
DOCKER_DIR=/mnt/wsl/shared-docker
DOCKER_SOCK="$DOCKER_DIR/docker.sock"
export DOCKER_HOST="unix://$DOCKER_SOCK"
if [ ! -S "$DOCKER_SOCK" ]; then
    mkdir -pm o=,ug=rwx "$DOCKER_DIR"
    chgrp docker "$DOCKER_DIR"
    /mnt/c/Windows/System32/wsl.exe -d $DOCKER_DISTRO sh -c "nohup sudo -b dockerd < /dev/null > $DOCKER_DIR/dockerd.log 2>&1"
fi
EOF

echo "Installation complete."
