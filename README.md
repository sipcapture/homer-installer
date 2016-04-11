![Logo](http://sipcapture.org/data/images/sipcapture_header.png)

# __HOMER 5__  Installer
This document provides guidance and details to get HOMER 5 installed using scripts or packages

![splitter](http://i.imgur.com/lytn4zn.png)

## Bash Installer
Supported OS:
* Debian 8
* CentOS 7

```
bash <( curl -s https://cdn.rawgit.com/lmangani/homer-installer/master/homer_installer.sh )
```


![splitter](http://i.imgur.com/lytn4zn.png)

## Packages
### Debian 8 
##### Create DEB Package
###### Requirements:
* [FPM](https://github.com/jordansissel/fpm) ```gem install fpm```

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

### CentOS 7 **[alpha test]**
##### Create RPM Package
###### Requirements:
* [FPM](https://github.com/jordansissel/fpm) ```gem install fpm```
* rpmbuild
```
cd /usr/src
git clone https://github.com/lmangani/homer-installer
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
