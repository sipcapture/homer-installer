<img src="https://user-images.githubusercontent.com/1423657/55069501-8348c400-5084-11e9-9931-fefe0f9874a7.png" width=300 />

# __HOMER 7__  Installer
This document provides guidance and details to get HOMER 7 installed stand-alone using scripts or packages

WARNING: Homer is rock-solid, while the installers and packages are experimental. Use at your own risk!<br>For a reliable and fine-tuned setup please carefully review each element and/or contact support@sipcapture.org for professional assistance.

Available Methods:

  * [BASH Installer](https://github.com/sipcapture/homer-installer#page_with_curl-bash-installer)
  * [DOCKER Containers](https://github.com/sipcapture/homer7-docker)

![splitter](http://i.imgur.com/lytn4zn.png)

## :page_with_curl: Bash Installer
The baseline installer expects a Vanilla OS and will install and configure:
* HOMER-APP 7.7
* HEPLIFY-SERVER 1.x
* PostgreSQL 13


Supported OS:
* Debian 10, 11
* CentOS 8, 9

### Run & Install:
Make sure the script is executed as root on a netinstall vanilla server. Execute the following command and follow the interactive prompts to install:

For Debian
```
apt-get install libluajit-5.1-common libluajit-5.1-dev lsb-release wget curl git
```

For CentOS
```
yum install redhat-lsb-core wget curl git
```

If you would like to install influxdb and chronograf:
```
cd /usr/src
wget https://raw.githubusercontent.com/sipcapture/homer-installer/master/telegraf.conf
```

Fianlly, download and run the Homer Installer script:
```
cd /usr/src
wget https://github.com/sipcapture/homer-installer/raw/master/homer_installer.sh
chmod +x homer_installer.sh
./homer_installer.sh
```

### Notes:
CentOS
* Ensure that the 'redhat-lsb-core' package is installed prior to running the installer.

![splitter](http://i.imgur.com/lytn4zn.png)

### Developers
Contributors and Contributions to our project are always welcome! If you intend to participate and help us improve HOMER by sending patches, we kindly ask you to sign a standard [CLA (Contributor License Agreement)](http://cla.qxip.net) which enables us to distribute your code alongside the project without restrictions present or future. It doesn’t require you to assign to us any copyright you have, the ownership of which remains in full with you. Developers can coordinate with the existing team via the [homer-dev](http://groups.google.com/group/homer-dev) mailing list. If you'd like to join our internal team and volounteer to help with the project's many needs, feel free to contact us anytime!


### License & Copyright

*Homer components are released under GNU AGPLv3 license*

*Captagent is released under GNU GPLv3 license*

*(C) 2008-2020 [SIPCAPTURE](http://sipcapture.org) & [QXIP BV](http://qxip.net)*

----------

##### If you use HOMER in production, please consider supporting the project with a [Donation](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=donation%40sipcapture%2eorg&lc=US&item_name=SIPCAPTURE&no_note=0&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest)

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=donation%40sipcapture%2eorg&lc=US&item_name=SIPCAPTURE&no_note=0&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHostedGuest) 
