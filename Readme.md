# docker-test-unboundid

The purpose of this repository is to provide an
[UnboundId](https://github.com/pingidentity/ldapsdk/) Docker image that can be
used for integration testing. The main goal being to be able to test the
VirtualListView control.

## Building And Running

1. Run `build.sh` to generate the image
2. Run `docker run --rm -it -p 389:10389 --name unboundid unboundid` to start
a server

### TODO NOTES

The idea is to build LDIFs from the known good openldap image and use those
LDIFs to star the UnboundId server. As of 2022-04-10, this isn't quite working.
The schema doesn't load correctly.

#### Start Server Manually
in-memory-directory-server --useStartTLS --generateSelfSignedCertificate \
  --port 10389 \
  --ldifFile ./data.ldif \
  --useSchemaFile ./config.ldif \
  --baseDN 'dc=planetexpress,dc=com'
