#!/bin/bash

if [[ ${1} == "checkdigests" ]]; then
    export DOCKER_CLI_EXPERIMENTAL=enabled
    image="alpine"
    tag="3.12"
    manifest=$(docker manifest inspect ${image}:${tag})
    [[ -z ${manifest} ]] && exit 1
    digest=$(echo "${manifest}" | jq -r '.manifests[] | select (.platform.architecture == "amd64" and .platform.os == "linux").digest') && sed -i "s#FROM ${image}@.*\$#FROM ${image}@${digest}#g" ./linux-amd64.Dockerfile  && echo "${digest}"
    digest=$(echo "${manifest}" | jq -r '.manifests[] | select (.platform.architecture == "arm" and .platform.os == "linux" and .platform.variant == "v7").digest') && sed -i "s#FROM ${image}@.*\$#FROM ${image}@${digest}#g" ./linux-arm-v7.Dockerfile && echo "${digest}"
    digest=$(echo "${manifest}" | jq -r '.manifests[] | select (.platform.architecture == "arm64" and .platform.os == "linux").digest') && sed -i "s#FROM ${image}@.*\$#FROM ${image}@${digest}#g" ./linux-arm64.Dockerfile  && echo "${digest}"
elif [[ ${1} == "tests" ]]; then
    echo "List installed packages..."
    docker run --rm --entrypoint="" "${2}" apk -vv info | sort
    echo "Check if app works..."
    echo "borg --version && export BORG_PASSPHRASE=testpassphrase && mkdir /tmp/borgtest && borg init --encryption=repokey-blake2 /tmp/borgtest && borg create --verbose --filter AME --list --stats --show-rc --compression lz4 --exclude-caches /tmp/borgtest::'{hostname}-{now}' /var/log/ && borg prune --list --prefix '{hostname}-' --show-rc --keep-daily 7 --keep-weekly 4 --keep-monthly 6 /tmp/borgtest" > borgtest.sh
    docker run --rm --entrypoint="" -v "${GITHUB_WORKSPACE}":"${GITHUB_WORKSPACE}" "${2}" sh "${GITHUB_WORKSPACE}/borgtest.sh"
else
    version=$(curl -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" -fsSL "https://api.github.com/repos/borgbackup/borg/releases/latest" | jq -r .tag_name | sed s/v//g)
    [[ -z ${version} ]] && exit 1
    old_version=$(jq -r '.version' < VERSION.json)
    changelog=$(jq -r '.changelog' < VERSION.json)
    [[ "${old_version}" != "${version}" ]] && changelog="https://github.com/borgbackup/borg/compare/${old_version}...${version}"
    echo '{"version":"'"${version}"'","changelog":"'"${changelog}"'"}' | jq . > VERSION.json
fi
