![Logo](http://sipcapture.org/data/images/sipcapture_header.png)

# __HOMER 5__  Installer
This document provides guidance and details to get HOMER 5 installed using packages

##### Requirements:
* [FPM](https://github.com/jordansissel/fpm) ```gem install fpm```

![splitter](http://i.imgur.com/lytn4zn.png)

## Debian 8 
##### Create DEB Package
```
cd /usr/src
git clone https://github.com/lmangani/homer-installer
cd homer-installer
./generate_deb.sh
```

##### Install DEB Package
NOTE: Dependencies will be resolved by the second step
```
dpkg -i ./homer-installer_5.0.5-1_amd64.deb
apt-get -f install
```

## CentOS 7 **[alpha test]**
##### Create RPM Package
```
cd /usr/src
git clone https://github.com/lmangani/homer-installer
cd homer-installer
./generate_rpm.sh
```
##### Install RPM Package
```
yum -y install wget
wget http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
yum -y localinstall mysql57-community-release-el7-7.noarch.rpm
wget http://download.opensuse.org/repositories/home:/kamailio:/v4.4.x-rpms/CentOS_7/home:kamailio:v4.4.x-rpms.repo -O /etc/yum.repos.d/kamailio.repo
yum install homer-installer-5.0.5-1.x86_64.rpm
```
