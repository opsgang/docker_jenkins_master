# vim: et sr sw=4 ts=4 smartindent syntax=dockerfile:
FROM jenkins:latest

# build.sh will use envsubst to replace all env vars in the
# LABEL instruction.
#
MAINTAINER jinal--shah <jnshah@gmail.com>
LABEL \
    name="jenkins_master" \
    vendor="sortuniq" \
    version="1.0.0" \
    description="creates jenkins to run as master"

ENV JENKINS_OPTS="--webroot=/var/cache/jenkins/war"     \
    DOCKER_APT_URI="https://apt.dockerproject.org/repo" \
    DOCKER_VERSION="1.12.3-0" \
    JENKINS_DIRS="/var/cache/jenkins" \
    CLEANUP_DIRS="/var/cache/apt/archives/ /var/lib/apt/*"

USER root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && apt-key adv \
        --keyserver hkp://p80.pool.sks-keyservers.net:80 \
        --recv-keys 58118E89F3A912897C070ADBF76221572C52609D \
    && echo "deb ${DOCKER_APT_URI} debian-jessie main" \
        > /etc/apt/sources.list.d/docker.list \
    && groupadd -g 233 docker \
    && usermod -a -G docker jenkins \
    && apt-get update \
    && apt-get install -y docker-engine=${DOCKER_VERSION}~jessie \
    && apt-get install -y jq sudo dnsutils \
    && echo "jenkins ALL=(ALL:ALL) NOPASSWD:/bin/rm" \
        > /etc/sudoers.d/jenkins \
    && sed -i 's/^\( *SendEnv\)/#\1/' /etc/ssh/ssh_config \
    && chmod 0440 /etc/sudoers.d/jenkins \
    && mkdir -p $JENKINS_DIRS \
    && chown -R jenkins:jenkins $JENKINS_DIRS \
    && rm -rf $CLEANUP_DIRS

USER jenkins
