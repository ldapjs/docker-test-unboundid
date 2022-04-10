#!/bin/bash

LDAP_PORT=${LDAP_PORT:-"10389"}
LDAP_QUERY=${LDAP_QUERY:-"(uid=admin)"}
LDAP_SEARCH_BASE=${LDAP_SEARCH_BASE:-'""'}

TRIES=0
READY=1
while [[ ${READY} -ne 0 && ${TRIES} -lt 9 ]]; do
  ldapsearch -x -H ldap://localhost:${LDAP_PORT}/ \
    -D ${LDAP_BINDDN} \
    -w ${LDAP_SECRET} \
    -b ${LDAP_SEARCH_BASE} \
    -LLL ${LDAP_QUERY} 2>/dev/null 1>/dev/null
  READY=$?
  TRIES=$((TRIES+1))
  sleep 2
done

if [ ${TRIES} -eq 9 ]; then
  echo "LDAP server not ready in allotted limit!"
  exit 1
fi
