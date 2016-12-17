#!/bin/bash
#
# --------------------------------------------------------------------------------
# HOMER/SipCapture automated installation script for Debian/CentOs/OpenSUSE (BETA)
# --------------------------------------------------------------------------------
# This script is only intended as a quickstart to test and get familiar with HOMER.
# It is not suitable for high-traffic nodes, complex capture scenarios, clusters.
# The HOW-TO should be ALWAYS followed for a fully controlled, manual installation!
# --------------------------------------------------------------------------------
#
#  Copyright notice:
#
#  (c) 2011-2016 Lorenzo Mangani <lorenzo.mangani@gmail.com>
#  (c) 2011-2016 Alexandr Dubovikov <alexandr.dubovikov@gmail.com>
#
#  All rights reserved
#
#  This script is part of the HOMER project (http://sipcapture.org)
#  The HOMER project is free software; you can redistribute it and/or 
#  modify it under the terms of the GNU Affero General Public License as 
#  published by the Free Software Foundation; either version 3 of 
#  the License, or (at your option) any later version.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  This copyright notice MUST APPEAR in all copies of the script!
#

#####################################################################
#                                                                   #
#  WARNING: THIS SCRIPT IS NOW UPDATED TO SUPPORT HOMER 5.x         #
#           PLEASE USE WITH CAUTION AND HELP US BY REPORTING BUGS!  #
#                                                                   #
#####################################################################

clear; 
echo "**************************************************************"
echo "                                                              "
echo "      ,;;;;;,       HOMER SIP CAPTURE (http://sipcapture.org) "
echo "     ;;;;;;;;;.     Single-Node Auto-Installer (beta $VERSION)"
echo "   ;;;;;;;;;;;;;                                              "
echo "  ;;;;  ;;;  ;;;;   <--------------- INVITE ---------------   "
echo "  ;;;;  ;;;  ;;;;    --------------- 200 OK --------------->  "
echo "  ;;;;  ...  ;;;;                                             " 
echo "  ;;;;       ;;;;   WARNING: This installer is intended for   "
echo "  ;;;;  ;;;  ;;;;   dedicated/vanilla OS setups without any   "
echo "  ,;;;  ;;;  ;;;;   customization and with default settings   "
echo "   ;;;;;;;;;;;;;                                              "
echo "    :;;;;;;;;;;     THIS SCRIPT IS PROVIDED AS-IS, USE AT     "
echo "     ^;;;;;;;^      YOUR *OWN* RISK, REVIEW LICENSE & DOCS    "
echo "                                                              "
echo "**************************************************************"
echo;


# Check if we're good on permissions
if  [ "$(id -u)" != "0" ]; then
  echo "ERROR: You must be a root user. Exiting..." 2>&1
  echo  2>&1
  exit 1
fi

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

echo "OS: Dectecting System...."
# Identify Linux Flavour
if [ -f /etc/debian_version ] ; then
    DIST="DEBIAN"
    echo "OS: DEBIAN detected"
elif [ -f /etc/redhat-release ] ; then
    DIST="CENTOS"
    VERS=$(cat /etc/redhat-release |cut -d' ' -f4 |cut -d'.' -f1)
    if [ "$VERS" = "7" ]; then
	    echo "OS: CENTOS 7 detected"
	    read -p "Support for CentOS is experimental and likely broken. Continue (y/N)? " choice
		case "$choice" in 
		  y|Y ) echo;;
		  n|N ) echo "Exiting" && exit 1;;
		  * ) echo "invalid" && exit 1 ;;
		esac
    fi
# elif [ -f /etc/SuSE-release ] ; then
#   DIST="SUSE"
#   echo "OS: SUSE detected"
else
    echo "ERROR:"
    echo "Sorry, this Installer does not support your OS yet!"
    echo "Please follow instructions in the HOW-TO for manual installation & setup"
    echo "available at http://sipcapture.org"
    echo
    exit 1
fi

function get_opensips {
        bash <( curl -s https://cdn.rawgit.com/sipcapture/homer-installer/master/homer_opensips_installer.sh ) && exit
}

function get_kamailio {
        bash <( curl -s https://cdn.rawgit.com/sipcapture/homer-installer/master/homer_kamailio_installer.sh ) && exit
}

echo "HEP SERVER: Please select your preference:"
echo
echo "   K) Kamailio 4.x"
echo "   O) OpenSIPS 2.2"
echo

read -p "Choose: (O)penSIPS or (K)amailio: " choice
case "$choice" in 
  k|K ) echo "Selecting Kamailio..." && get_kamailio;;
  o|O ) echo "Selecting OpenSIPS" && get_opensips;;
  * ) echo "Invalid Choice! Exiting... " && exit 1 ;;
esac
