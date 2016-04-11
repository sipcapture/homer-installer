#!/bin/bash
echo "Generating RPM Installer Package..."
fpm -s dir -t rpm -C ./data/ --name homer-installer --version 5.0.5 --iteration 1 --license AGPL3 --vendor "SIPCAPTURE" --url "http://sipcapture.org" \
--description "Homer 5 Installer" --template-scripts --after-install ./data/usr/src/homer-installer/rpm_install.sh \
--depends autoconf,automake,bzip2,cpio,curl,curl-devel,curl-devel,expat-devel,fileutils,make,gcc,gcc-c++,gettext-devel,gnutls-devel,openssl,openssl-devel,openssl-devel,mod_ssl,perl,patch,unzip,wget,zip,zlib,zlib-devel,bison,flex,pcre-devel,libxml2-devel,sox,httpd,php,php-gd,php-mysql,php-json,git,php-mysql,php-devel,mysql-community-server,kamailio,rsyslog,kamailio-outbound,kamailio-sctp,kamailio-tls,kamailio-websocket,kamailio-jansson,kamailio-mysql
ls -alF ./*.rpm

