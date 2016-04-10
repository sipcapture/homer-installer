# homer-installer
HOMER 5 Installer 

##### DEB Build
```
# Generate DEB Package
cd /usr/src
git clone https://github.com/lmangani/homer-installer
cd homer-installer
./generate_deb.sh
# Install DEB Package
dpkg -i ./homer-installer_5.0.5-1_amd64.deb
apt-get -f install
```
