# vim: et sr sw=4 ts=4 smartindent syntax=dockerfile:
FROM jenkins:latest

LABEL \
    name="opsgang/jenkins_master" \
    vendor="sortuniq" \
    description="creates jenkins to run as master"

ENV \
    CLEANUP_DIRS="/var/cache/apt/archives/ /var/lib/apt/*" \
    DEBIAN_FRONTEND=noninteractive \
    DOCKER_APT_URI="https://apt.dockerproject.org/repo" \
    DOCKER_GID="233" \
    DOCKER_VERSION="1.12.6-0~debian-jessie" \
    JENKINS_DIRS="/var/cache/jenkins" \
    JENKINS_OPTS="--webroot=/var/cache/jenkins/war"

USER root

RUN apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && apt-key adv \
        --keyserver hkp://p80.pool.sks-keyservers.net:80 \
        --recv-keys 58118E89F3A912897C070ADBF76221572C52609D \
    && echo "deb ${DOCKER_APT_URI} debian-jessie main" \
        > /etc/apt/sources.list.d/docker.list \
    && groupadd -g ${DOCKER_GID} docker \
    && usermod -a -G docker jenkins \
    && apt-get update \
    && apt-get install -y docker-engine=${DOCKER_VERSION} \
    && apt-get -t jessie-backports install -y jq \
    && apt-get install -y sudo dnsutils \
    && echo "jenkins ALL=(ALL:ALL) NOPASSWD:/bin/rm" \
        > /etc/sudoers.d/jenkins \
    && sed -i 's/^\( *SendEnv\)/#\1/' /etc/ssh/ssh_config \
    && chmod 0440 /etc/sudoers.d/jenkins \
    && mkdir -p $JENKINS_DIRS \
    && chown -R jenkins:jenkins $JENKINS_DIRS \
    && rm -rf $CLEANUP_DIRS

USER jenkins
