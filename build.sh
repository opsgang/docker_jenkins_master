#!/bin/bash
# vim: et sr sw=4 ts=4 smartindent:
# helper script to generate label data for docker image during building
#
# docker_build will generate an image tagged :candidate
#
# It is a post-step to tag that appropriately and push to repo.
# Shippable handles this part.

MIN_DOCKER=1.11.0
GIT_SHA_LEN=8
IMG_TAG=candidate
# ... create log prefix
SC=$( if [[ $0 =~ ^-?bash$ ]]; then echo "bash"; else basename $(realpath -- $0); fi )

version_gt() {
    [[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" ]]
}

valid_docker_version() {
    v=$(docker --version | grep -Po '\b\d+\.\d+\.\d+\b')
    if version_gt $MIN_DOCKER $v
    then
        red_e "... need min docker version $MIN_DOCKER"
        return 1
    fi
}

# ... for log msgs
e() {
    echo -e "ERROR $SC: $*" >&2
}

i() {
    echo -e "INFO $SC: $*"
}

bold_i() {
    i "\033[1;37m${*}\033[0m"
}

yellow_i() {
    i "\033[1;33m${*}\033[0m"
}

red_e() {
    e "\033[1;31m${*}\033[0m"
}

base_img() {
    grep -Po '(?<=^FROM ).*' Dockerfile
}

init_img() {
    docker pull "$1" >/dev/null 2>&1
}

docker_version() {
    grep -Po '(?<= DOCKER_VERSION=")[^"]+' Dockerfile
}

jenkins_version() {
    local bi="$1"
    (
        set -o pipefail
        docker inspect $bi \
        | jq -r '.[].Config.Env[] | select(startswith("JENKINS_VERSION="))' \
        | awk -F= {'print $NF'}
    ) || return 1
}

pkg_version() {
    local bi="$1"
    local pkg="$2"
    local c=$(date +'%Y%m%d%H%M%S')
    if [[ -z "$bi" ]] || [[ -z "$pkg" ]]; then
        red_e "... build.sh pkg_version() - must be passed base image and pkg name"
        return 1
    fi
    local cmd="
        apt-get update >/dev/null 2>&1 && apt-cache show $pkg
        | grep -Po '(?<=^Version: ).*'
        | head -n 1
    " ; cmd="$(echo $cmd)"

    docker run --name $c -u root --rm $bi /bin/bash -c "$cmd" || return 1
}

built_by() {
    local user="--UNKNOWN--"
    if [[ ! -z "${BUILD_URL}" ]]; then
        user="${BUILD_URL}"
    elif [[ ! -z "${AWS_PROFILE}" ]] || [[ ! -z "${AWS_ACCESS_KEY_ID}" ]]; then
        user="$(aws iam get-user --query 'User.UserName' --output text)@$HOSTNAME"
    else
        user="$(git config --get user.name)@$HOSTNAME"
    fi
    echo "$user"
}

git_uri(){
    git config remote.origin.url || echo 'no-remote'
}

git_sha(){
    git rev-parse --short=${GIT_SHA_LEN} --verify HEAD
}

git_branch(){
    r=$(git rev-parse --abbrev-ref HEAD)
    [[ -z "$r" ]] && red_e "... no rev to parse when finding branch? " >&2 && return 1
    [[ "$r" == "HEAD" ]] && r="from-a-tag"
    echo "$r"
}

img_name(){
    (
        set -o pipefail;
        grep -Po '(?<=[nN]ame=")[^"]+' Dockerfile | head -n 1
    )
}

labels() {
    bi=$(base_img) || return 1
    init_img "$bi" || return 1

    dv=$(docker_version) || return 1
    jev=$(jenkins_version "$bi") || return 1
    jqv=$(pkg_version "$bi" "jq") || return 1
    gu=$(git_uri) || return 1
    gs=$(git_sha) || return 1
    gb=$(git_branch) || return 1
    gt=$(git describe 2>/dev/null || echo "no-git-tag")
    bb=$(built_by) || return 1

    cat<<EOM
    --label version=$(date +'%Y%m%d%H%M%S')
    --label opsgang.docker_version=$dv
    --label opsgang.jenkins_version=$jev
    --label opsgang.jq_version=$jqv
    --label opsgang.build_git_uri=$gu
    --label opsgang.build_git_sha=$gs
    --label opsgang.build_git_branch=$gb
    --label opsgang.build_git_tag=$gt
    --label opsgang.built_by="$bb"
EOM
}

docker_build(){

    bold_i "STARTING build process ..."
    valid_docker_version || return 1

    i "... generating docker labels"
    labels=$(labels) || return 1
    n=$(img_name) || return 1

    i "... adding these labels:"
    echo "$labels"
    i "... building $n:$IMG_TAG"

    docker build --no-cache=true --force-rm $labels -t $n:$IMG_TAG .
}

docker_build
