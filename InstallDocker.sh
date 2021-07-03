#!/bin/bash

echo "Installing Docker"

apk del docker-cli docker-engine docker-openrc docker-compose docker shadow curl
apk update
apk upgrade -U

apk add docker --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
addgroup $USER docker

sed -i -e 's/^\(docker:x\):[^:]\+/\1:36257/' /etc/group
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

tee -a ~/.profile <<EOF
export DOCKER_HOST="unix:///mnt/wsl/shared-docker/docker.sock"
if [ ! -S "/mnt/wsl/shared-docker/docker.sock" ]; then
    mkdir -pm o=,ug=rwx /mnt/wsl/shared-docker
    chgrp docker /mnt/wsl/shared-docker
fi

if [ ! psgrep dockerd > 0 ]; then
    /mnt/c/Windows/System32/wsl.exe -d LocalDockerHost sh -c "nohup dockerd < /dev/null > $DOCKER_DIR/dockerd.log 2>&1" &
fi
EOF