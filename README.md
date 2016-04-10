# homer-installer
HOMER 5 Installer 

##### Create DEB Package (FPM)
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
