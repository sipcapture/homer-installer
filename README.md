![Logo](http://sipcapture.org/data/images/sipcapture_header.png)

# __HOMER 5__  Installer
This document provides guidance and details to get HOMER 5 installed stand-alone using scripts or packages

WARNING: The installer and packages are experimental. Use at your own risk! For a reliable and fine-tuned setup please carefully review each element and/or contact support@sipcapture.org team for professional assistance.

![splitter](http://i.imgur.com/lytn4zn.png)

## :page_with_curl: Bash Installer
The baseline installer expects a Vanilla OS and will install and configure:
* Homer 5.x
* Kamailio 4.4
* MySQL 5.7
* Apache2 + PHP5

Supported OS:
* Debian 8
* CentOS 7

### Run & Install:
Execute the following command and follow the interactive prompts to install:
```
bash <( curl -s https://cdn.rawgit.com/sipcapture/homer-installer/master/homer_installer.sh )
```


![splitter](http://i.imgur.com/lytn4zn.png)

## :package: Packages
### :package: Debian 8 
##### :page_with_curl: Create DEB Package
###### Requirements:
* [FPM](https://github.com/jordansissel/fpm) ```gem install fpm```

```
cd /usr/src
git clone https://github.com/sipcapture/homer-installer
cd homer-installer
./generate_deb.sh
```

##### Install DEB Package

NOTE: Dependencies will be resolved by the second step
```
dpkg -i ./homer-installer_5.0.5-1_amd64.deb
apt-get -f install
```

### :package: CentOS 7 **[alpha]**
##### :page_with_curl: Create RPM Package
###### Requirements:
* [FPM](https://github.com/jordansissel/fpm) ```gem install fpm```
* rpmbuild
```
cd /usr/src
git clone https://github.com/sipcapture/homer-installer
cd homer-installer
./generate_rpm.sh
```
##### Install RPM Package
Note: The script might prompt for mysql password multiple times if needed
```
yum -y install wget
wget http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
yum -y localinstall mysql57-community-release-el7-7.noarch.rpm
wget http://download.opensuse.org/repositories/home:/kamailio:/v4.4.x-rpms/CentOS_7/home:kamailio:v4.4.x-rpms.repo -O /etc/yum.repos.d/kamailio.repo
yum install homer-installer-5.0.5-1.x86_64.rpm
```
