# docker_jenkins_master
<!--
    vim: et sr sw=4 ts=4 smartindent syntax=markdown:
-->

_... creates a jenkins container with docker engine ..._

Built @ shippable.com [![Run Status](https://api.shippable.com/projects/589464f08d80360f008b7550/badge?branch=master)](https://app.shippable.com/github/opsgang/docker_jenkins_master)

It is intended to run mounting the docker daemon on the host.

**By default, docker group's gid is 233 in the container.**

**We try to peg the _stable_ tag's docker-engine version to that used by CoreOS stable.**

If you are mounting the docker daemon from the host, the docker group in the container
must have the same GID as the group id of the docker.sock file on the host.

This will allow the container's jenkins user to use the host's docker daemon.

You should also use a version of the docker-engine that is compatible with that on
the host. Ideally, use the same version.

**See below to use a different GID or install a different engine version.**

If you wish to persist JENKINS\_HOME on the host, make sure the dir is writable by
the jenkins user in the container (uid/gid of 1000)

## HOWTO: ... run

```bash
# - expose http on host port 80
# - use host's docker daemon
# - use host dir /var/lib/jenkins to persist JENKINS_HOME
docker run -d --name my_jenxs \
    -p 80:8080 -p 50000:50000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/jenkins:/var/jenkins_home \
    opsgang/jenkins_master:stable
```

## HOWTO: ... change docker gid or engine version

Write a Dockerfile e.g. for engine 1.11.2, gid 500

        # Dockerfile
        FROM opsgang/jenkins_master:stable

        USER root

        RUN apt-get update \
        && apt-get remove docker-engine \
        && apt-get install -y docker-engine=1.11.2-0~jessie
        && groupmod -g 500 docker

        USER jenkins

**For more recent engine versions use `apt-get -t jessie-backports install -y <desired version>`**.

To discover what versions are available run:

```bash
cmd="apt-get update >/dev/null 2>&1 && apt-cache show docker-engine | grep -Po '^(?<=Version: ).*'"
docker run --rm -u root opsgang/jenkins_master:stable /bin/bash -c "$cmd"
```

## HOWTO: ... run with systemd

Most important is this line:

        -v /var/run/docker.sock:/var/run/docker.sock

That allows the docker client within the jenkins container to use the
host's docker daemon.

The other mounted vols contain shell functions and config info
that already exist on the host, which jenkins jobs can source and
take advantage of.


        # /etc/systemd/system/jenkins_master.service
        # ... assumes you want to persist JENKINS_HOME on the container's host
        [Unit]
        Description=Jenkins Master
        After=docker.socket
        Requires=docker.socket

        [Service]
        Restart=always
        RestartSec=60
        TimeoutStartSec=0
        Environment="_C=jenkins_master"
        Environment="_DI=opsgang/jenkins_master:stable"
        Environment="JENKINS_HOME=/path/on/host"
        ExecStartPre=/bin/mkdir -p ${JENKINS_HOME}
        ExecStartPre=/usr/bin/sudo -E /bin/chown -R 1000:1000 ${JENKINS_HOME}
        ExecStartPre=-/usr/bin/docker stop ${_C}
        ExecStartPre=-/usr/bin/docker rm -f ${_C}
        ExecStartPre=/usr/bin/docker pull ${_DI}
        ExecStart=/bin/bash -c " \
        docker run --name ${_C} \
            -p 80:8080 -p 50000:50000 \
            -v ${JENKINS_HOME}:/var/jenkins_home \
            -v /var/run/docker.sock:/var/run/docker.sock \
            ${_DI}"

        ExecStop=/usr/bin/docker stop ${_C}

        [Install]
        WantedBy=multi-user.target

## HOWTO: ... get a list of installed plugins and versions

```
If your jenkins is using github auth, you'll need your api token.

Access your jenkins user's configuration via a browser:

        e.g. https://<myjenks.example.com>/user/<my.github.name>/configure

Get the value from the corresponding _API Token_ section.
```

Exec a shell in your running jenkins container:

```bash

docker exec -it jenkins_master /bin/bash

# ... from WITHIN the container ...
curl --user <my.github.name>:<api token> \
    -sSL "http://localhost:8080/pluginManager/api/xml?depth=1&xpath=/*/*/shortName|/*/*/version&wrapper=plugins" \
| perl -pe 's/.*?<shortName>([\w-]+).*?<version>([^<]+)()(<\/\w+>)+/\1 \2\n/g'|sed 's/ /:/'
```

That'll print a list of plugin:version to STDOUT.

```
That output as a file is suitable for consumption by /usr/local/bin/plugins.sh (deprecated).

You can also use the newer install-plugins.sh:
```

```bash
/usr/local/bin/install-plugins.sh $(cat plugins-from-curl-cmd.txt)
```

