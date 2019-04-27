#!/usr/bin/env bash

set -e -x -u -o pipefail

source "tools/circleci/decrypt_token.sh"
source "tools/version.sh"

readonly REPO_ENDPOINT="https://api.github.com/repos/dual-lab/make-build-thing"
readonly AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
readonly CONTENT_TYPE="Content-Type:Application/json"
##
# name   : release.sh
# author : dmike
# scope  : release a new version of the lib
#        creating a new rel on github and uploading the artifact
##
function main() {
    
    assert_master_branch

    local tag="v${MAJOR}.${MINOR}.${PATCH}"

    assert_no_tag_version ${tag}

    local bundle_name="mkbts"
    local artifactid="${bundle_name}-${tag}"

    generate_bundle ${artifactid}
    ## TODO function that extract portion of changelog
    generate_release ${tag} ${artifactid}
}

function generate_bundle(){
    tar -zcvf "$1.tar.gz" \
    KBUILD Makefile LICENSE CHANGELOG.md README.md \
    scripts/

    return $?
}

function assert_master_branch(){
    local current_branch="$(git rev-parse --abbrev-ref  HEAD)"
    local expected_branch="master"
    
    if [[ "$current_branch" == "$expected_branch" ]]; then
        return 0
    else
        printf "++ Release only on branch master\n"
        return 1
    fi
}

function assert_no_tag_version(){
    local v_tag=$1
    local tag_url="${REPO_ENDPOINT}/releases/tags/${v_tag}"
    local status=$(curl --silent -H "${AUTH_HEADER}" --head ${tag_url} | awk '/Status:/ {print $2}')

    if [[ ${status} -eq 404 ]]; then
        return 0
    else
        printf "++ Release with tag ${tag}, already exists\n"
        return 1
    fi 
}

function generate_release(){
    local rel_url="${REPO_ENDPOINT}/release"
    local rel_payload="{\"tag_name\":\"$1\", \"name\":\"$1\",\"draft\":true,\"body\":$3 }"
    local awk_program='BEGIN{FS="\":"} /current_user_url/ {print substr($NF,1,length($NF)-1)}'
    local upload_url=$(curl --silent -H "${AUTH_HEADER}" -H "${CONTENT_TYPE}" -d ${rel_payload} ${rel_url} | awk "${awk_program}")
}

main