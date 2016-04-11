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

![splitter](http://i.imgur.com/lytn4zn.png)


### Developers
Contributors and Contributions to our project are always welcome! If you intend to participate and help us improve HOMER by sending patches, we kindly ask you to sign a standard [CLA (Contributor License Agreement)](http://cla.qxip.net) which enables us to distribute your code alongside the project without restrictions present or future. It doesn’t require you to assign to us any copyright you have, the ownership of which remains in full with you. Developers can coordinate with the existing team via the [homer-dev](http://groups.google.com/group/homer-dev) mailing list. If you'd like to join our internal team and volounteer to help with the project's many needs, feel free to contact us anytime!




### License & Copyright

*Homer components are released under GNU AGPLv3 license*

*Captagent is released under GNU GPLv3 license*

*(C) 2008-2016 [SIPCAPTURE](http://sipcapture.org) & [QXIP BV](http://qxip.net)*

----------

##### If you use HOMER in production, please consider supporting the project with a [Donation](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=donation%40sipcapture%2eorg&lc=US&item_name=SIPCAPTURE&no_note=0&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest)

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=donation%40sipcapture%2eorg&lc=US&item_name=SIPCAPTURE&no_note=0&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest) 
