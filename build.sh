#!/bin/bash

# Define the remote Docker registry to push the final image to.
DOCKER_REGISTRY=${DOCKER_REGISTRY:-'ghcr.io/ldapjs/docker-test-unboundid'}

# Set to 1 to push the final image to the remote registry, e.g.:
# `PUSH=1 ./build.sh`
#
# Remember to authenticate to the registry:
# https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry
PUSH=${PUSH:-0}

# First input = local dest name
# Second input = URL
function downloadPackage() {
  mkdir -p packages 2>&1 > /dev/null
  if [ ! -e packages/${1} ]; then
    echo "Downloading ${1}..."
      curl --progress-bar -L -o packages/${1} ${2}
  fi
}

function trap_handler() {
  return_value=$?
  if [ ${return_value} -ne 0 ]; then
    echo 'Build failed!'
    exit ${return_value}
  fi
}
trap "trap_handler" INT TERM EXIT ERR

set -e

SDK_URL=$(
  curl -s https://api.github.com/repos/pingidentity/ldapsdk/releases | \
  jq -r 'map(select(.draft == false and .prerelease == false)) | .[0].assets | map(select(.name | test("unboundid-ldapsdk-.+?.zip"))) | .[0].browser_download_url'
)
INIT_URL=$(
  curl -s https://api.github.com/repos/Yelp/dumb-init/releases | \
  jq -r 'map(select(.draft == false and .prerelease == false)) | .[0].assets | map(select(.name | test("dumb-init_.+?_x86_64"))) | .[0].browser_download_url'
)

echo "Downloading resources ..."
downloadPackage unboundid.zip ${SDK_URL}
downloadPackage dumb-init ${INIT_URL}
chmod +x packages/dumb-init

if [ ! -d build_out ]; then
  mkdir build_out
fi

echo "Dumping data from openldap container ..."
docker run --rm -d \
  --name openldap-tmp \
  -p 389:389 \
  -v $(pwd)/build_out:/export \
  ghcr.io/ldapjs/docker-test-openldap/openldap 1>/dev/null
export LDAP_PORT=389
export LDAP_SEARCH_BASE="dc=planetexpress,dc=com"
export LDAP_QUERY='(uid=amy)'
export LDAP_BINDDN='cn=admin,dc=planetexpress,dc=com'
export LDAP_SECRET='GoodNewsEveryone'
./tools/ldap-ready.sh
wait
docker exec -w /export openldap-tmp bash -c "cp /etc/ldap/schema/core.schema ."
docker exec -w /export openldap-tmp bash -c "cp /etc/ldap/schema/cosine.schema ."
docker exec -w /export openldap-tmp bash -c "cp /etc/ldap/schema/nis.schema ."
docker exec -w /export openldap-tmp bash -c "cp /etc/ldap/schema/inetorgperson.schema ."
docker exec -w /export openldap-tmp bash -c "slapcat -n 0 -l config.ldif"
docker exec -w /export openldap-tmp bash -c "slapcat -n 1 -l data.ldif"
docker kill openldap-tmp 1>/dev/null

cat build_out/core.schema \
  build_out/cosine.schema \
  build_out/nis.schema \
  build_out/inetorgperson.schema \
  build_out/config.ldif > build_out/schema.schema
rm build_out/config.ldif
mv build_out/schema.schema build_out/config.ldif

echo "Building image ..."
docker build -t unboundid-bootstrap -f Dockerfile.bootstrap .

# docker run --rm \
#   -v $(pwd)/build_out:/build_out \
#   unboundid-bootstrap

# docker build -t unboundid -f Dockerfile.final .

# d=$(date +'%Y-%m-%d')
# docker tag unboundid ${DOCKER_REGISTRY}/unboundid:${d}
# docker tag unboundid ${DOCKER_REGISTRY}/unboundid:latest

# if [ ${PUSH} -eq 1 ]; then
#   docker push ${DOCKER_REGISTRY}/unboundid:${d}
#   docker push ${DOCKER_REGISTRY}/unboundid:latest
# fi
