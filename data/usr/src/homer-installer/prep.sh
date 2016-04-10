#!/bin/bash
# (C) 2016 sipcapture.org
# All Rights Reserved

echo "OS: Dectecting System...."
# Identify Linux Flavour
if [ -f /etc/debian_version ] ; then
    DIST="DEBIAN"
    echo "OS: DEBIAN detected"
	echo "Installing Kamailio 4.4 repository..."
	{
		# Kamailio 4.4 repository
		apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xfb40d3e6508ea4c8
		echo "deb http://deb.kamailio.org/kamailio44 jessie main" >> /etc/apt/sources.list
		echo "deb-src http://deb.kamailio.org/kamailio44 jessie main" >> /etc/apt/sources.list
	} &> /dev/null

	echo "Installing MySQL 5.7 repository..."
	{
		# MySQL 5.7 repository
		apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5
		echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-5.7" > /etc/apt/sources.list.d/mysql.list
	} &> /dev/null

	echo "Sync repositories..."
	apt-get update
	# echo "Install required packages..."
	# apt-get install -y ca-certificates apache2 libapache2-mod-php5 php5 php5-cli php5-gd php-pear php5-dev php5-mysql php5-json php-services-json git wget pwgen perl libdbi-perl libclass-dbi-mysql-perl mysql-server-5.7 libmysqlclient18 kamailio rsyslog kamailio-outbound-modules kamailio-geoip-modules kamailio-sctp-modules kamailio-tls-modules kamailio-websocket-modules kamailio-utils-modules kamailio-mysql-modules kamailio-extra-modules geoip-database geoip-database-extra
	#clear
	echo
	echo "Done! It's HOMER time! To complete the setup please run:"
	echo
	echo "     apt-get -y install -f"
	echo
# elif [ -f /etc/redhat-release ] ; then
#    DIST="CENTOS"
#    echo "OS: CENTOS detected"
# elif [ -f /etc/SuSE-release ] ; then
#   DIST="SUSE"
#   echo "OS: SUSE detected"
else
    echo "ERROR:"
    echo "Sorry, this Installer supports Debian flavoures systems only!"
    echo "Please follow instructions in the HOW-TO for manual installation & setup"
    echo "available at http://sipcapture.org"
    echo
    exit 1
fi





