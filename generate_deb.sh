#!/bin/bash
echo "Generating Installer Package..."
fpm -s dir -t deb -C ./deb/ --name homer-installer --version 5.0.5 --iteration 1 --license AGPL3 --vendor "SIPCAPTURE" --url "http://sipcapture.org" \
--deb-no-default-config-files --description "Homer 5 Installer" --before-install ./deb/usr/src/homer-installer/prep.sh --after-install ./deb/usr/src/homer-installer/install.sh \
--depends ca-certificates,apache2,libapache2-mod-php5,php5,php5-cli,php5-gd,php-pear,php5-dev,php5-mysql,php5-json,php-services-json,git,wget,perl,libdbi-perl,libclass-dbi-mysql-perl,mysql-server,libmysqlclient18,kamailio,rsyslog,kamailio-outbound-modules,kamailio-geoip-modules,kamailio-sctp-modules,kamailio-tls-modules,kamailio-websocket-modules,kamailio-utils-modules,kamailio-mysql-modules,kamailio-extra-modules,geoip-database,geoip-database-extra

ls -alF ./*.deb

