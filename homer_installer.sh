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
#  (c) 2011-2019 QXIP BV, Amsterdam NL
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

[[ "$TRACE" ]] && { set -x; set -o functrace; }

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

logfile="/tmp/$(basename $0).$$.log"
exec > >(tee -ia $logfile)
exec 2> >(tee -ia $logfile >&2)

trap 'exit 1' TERM
my_pid=$$


# HOMER Options, defaults
DB_USER="homer_user"
DB_PASS=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
DB_HOST="localhost"
LISTEN_PORT="9060"
CHRONOGRAF_LISTEN_PORT="8888"
INSTALL_INFLUXDB=""

GO_VERSION="1.12.4"
OS=`uname -s`
HOME_DIR=$HOME
CURRENT_DIR=`pwd`
GO_HOME=$HOME_DIR/go
GO_ROOT=/usr/local/go
ARCH=`uname -m`

#### NO CHANGES BELOW THIS LINE! 

VERSION=7.0
SETUP_ENTRYPOINT=""
OS=""
DISTRO=""
DISTRO_VERSION=""

######################################################################
#
# Start of function definitions
#
######################################################################
is_root_user() {
  # Function to check that the effective user id of the user running
  # the script is indeed that of the root user (0)

  if [[ $EUID != 0 ]]; then
    return 1
  fi
  return 0
}


install_golang() {
  echo
  if [ -d /usr/local/go ]; then
    echo "...... [ Found an older version of GO ]"
    printf "Would you like to remove it? [y/N]: "
    read ans
    case "$ans" in
    	"y"|"yes"|"Y"|"Yes"|"YES") rm -rf /usr/local/go;;
    	*) return 0;;
    esac
  fi
  # If the operating system is 64-bit Linux
  if [ "$OS" == "Linux" ] && [ "$ARCH" == "x86_64" ]; then
    PACKAGE=go$GO_VERSION.linux-amd64.tar.gz
    pushd /tmp > /dev/null
    echo
    wget --no-check-certificate https://storage.googleapis.com/golang/$PACKAGE
    if [ $? -ne 0 ]; then
    	echo "Failed to Download the package! Exiting."
    	exit 1
    fi
    tar -C /usr/local -xzf $PACKAGE
    rm -rf $PACKAGE
    popd > /dev/null
    setup
  fi
}

setup() {
  if [ ! -d $GO_HOME ]; then
    mkdir $GO_HOME
    mkdir -p $GO_HOME/{src,pkg,bin}
  else
    mkdir -p $GO_HOME/{src,pkg,bin}
  fi
  if [ "$OS" == "Linux" ] && [ "$ARCH" == "x86_64" ]; then
    grep -q -F 'export GOPATH=$HOME/go' $HOME/.bashrc || echo 'export GOPATH=$HOME/go' >> $HOME/.bashrc
    grep -q -F 'export GOROOT=/usr/local/go' $HOME/.bashrc || echo 'export GOROOT=/usr/local/go' >> $HOME/.bashrc
    grep -q -F 'export PATH=$PATH:$GOROOT/bin' $HOME/.bashrc || echo 'export PATH=$PATH:$GOROOT/bin' >> $HOME/.bashrc
    grep -q -F 'export PATH=$PATH:$GOPATH/bin' $HOME/.bashrc || echo 'export PATH=$PATH:$GOPATH/bin' >> $HOME/.bashrc
  fi
  install_heplify_server
}
have_commands() {
  # Function to check if we can find the command(s) passed to us
  # in the systems PATH
  local cmd_list="$1"
  local -a not_found=() 
  
  for cmd in $cmd_list; do
    command -v $cmd >/dev/null 2>&1 || not_found+=("$cmd")
  done
  
  if [[ ${#not_found[@]} == 0 ]]; then
    # All commands found
    return 0
  else
    # Something not found
    return 1
  fi
}

locate_cmd() {
  # Function to return the full path to the cammnd passed to us
  # Make sure it exists on the system first or else this exits
  # the script execution
  local cmd="$1"
  local valid_cmd=""
  # valid_cmd=$(hash -t $cmd 2>/dev/null)
  valid_cmd=$(command -v $cmd 2>/dev/null)
  if [[ ! -z "$valid_cmd" ]]; then
    echo "$valid_cmd"
  else
    echo "HALT: Please install package for command '$cmd'"
    /bin/kill -s TERM $my_pid
  fi
  return 0
}

is_supported_os() {
  # Function to see if the OS is a supported type, the 1st 
  # parameter passed should be the OS type to check. The bash 
  # shell has a built in variable "OSTYPE" which should be 
  # sufficient for a start

  local os_type=$1

  case "$os_type" in
    linux* ) OS="Linux"
             minimal_command_list="lsb_release wget curl git"
             if ! have_commands "$minimal_command_list"; then
               echo "ERROR: You need the following minimal set of commands installed:"
               echo ""
               echo "       $minimal_command_list"
               echo ""
               exit 1
             fi
             detect_linux_distribution # Supported OS, Check if supported distro.
             return ;;  
    *      ) return 1 ;;               # Unsupported OS
  esac
}

detect_linux_distribution() {
  # Function to see if a specific linux distribution is supported by this script
  # If it is supported then the global variable SETUP_ENTRYPOINT is set to the 
  # function to be executed for the system setup

  local cmd_lsb_release=$(locate_cmd "lsb_release")
  local distro_name=$($cmd_lsb_release -si)
  local distro_version=$($cmd_lsb_release -sr)
  DISTRO="$distro_name"
  DISTRO_VERSION="$distro_version"

  case "$distro_name" in
    Debian ) case "$distro_version" in
               9* ) SETUP_ENTRYPOINT="setup_debian_9"
                    return 0 ;; # Suported Distribution
               *  ) return 1 ;; # Unsupported Distribution
             esac
             ;;
    CentOS ) case "$distro_version" in
               7* ) SETUP_ENTRYPOINT="setup_centos_7"
                    return 0 ;; # Suported Distribution
               *  ) return 1 ;; # Unsupported Distribution
             esac
             ;;
    *      ) return 1 ;; # Unsupported Distribution
 esac
}

check_status() {
  # Function to check and do something with the return code of some command

  local return_code="$1"

  if [[ $return_code != 0 ]]; then
    echo "HALT: Return code of command was '$return_code', aborting."
    echo "Please check the log above and correct the issue."
    exit 1
  fi
}

repo_clone_or_update() {
  # Function to clone a repository or update if it already exists locally
  local base_dir=$1
  local dest_dir=$2
  local git_repo=$3
  local git_branch=${4:-"origin/master"}
  local cmd_git=$(locate_cmd "git")

  if [ -d "$base_dir" ]; then
    cd "$base_dir"
    if [ -d "$dest_dir" ]; then
      cd $dest_dir
      # $cmd_git pull
      $cmd_git fetch --all
      $cmd_git reset --hard "$git_branch"
      check_status "$?"
    else
      $cmd_git clone --depth 1 "$git_repo" "$dest_dir"
      check_status "$?"
    fi
    return 0
  else
    return 1
  fi
}

create_heplify_service() {
  local sys_systemd_base='/lib/systemd/system'
  local usr_systemd_base='/etc/systemd/system'
  local sys_heplify_svc='heplify-server.service'
  local sys_postgresql_svc=''

  local cmd_systemctl=$(locate_cmd "systemctl")
  local cmd_cat=$(locate_cmd "cat")
  local cmd_mkdir=$(locate_cmd "mkdir")

  if [ -d $sys_systemd_base ]; then
    if [ -f $sys_systemd_base/postgresql.service ]; then
      sys_postgresql_svc=postgresql.service
    fi

    if [ ! -f $sys_systemd_base/$sys_heplify_svc ]; then
      $cmd_cat << __EOFL__ > $sys_systemd_base/$sys_heplify_svc
[Unit]
Description=HEP Server & Switch in Go
After=network.target

[Service]
WorkingDirectory=/opt/heplify-server
ExecStart=/opt/heplify-server/heplify-server
ExecStop=/bin/kill \${MAINPID}
Restart=on-failure
RestartSec=10s
Type=simple

[Install]
WantedBy=multi-user.target
__EOFL__
      check_status "$?"
    fi
    if [ ! -d $usr_systemd_base/${sys_heplify_svc}.d ]; then
      $cmd_mkdir -m 0755 -p $usr_systemd_base/${sys_heplify_svc}.d
      check_status "$?"
    fi
    if [ ! -f $usr_systemd_base/${sys_heplify_svc}.d/require_postgresql.conf ] && \
       [ ! -z "$sys_postgresql_svc" ]; then
      $cmd_cat << __EOFL__ > $usr_systemd_base/${sys_heplify_svc}.d/require_postgresql.conf
[Unit]
After= $sys_postgresql_svc
__EOFL__
      check_status "$?"
    fi
    $cmd_systemctl daemon-reload
    check_status "$?"
    $cmd_systemctl enable $sys_heplify_svc 
    check_status "$?"
    $cmd_systemctl start $sys_heplify_svc 
    check_status "$?"
  fi
}

setup_heplify_server(){
  local cmd_curl=$(locate_cmd "curl")
  local cmd_wget=$(locate_cmd "wget")
  local cmd_grep=$(locate_cmd "grep")
  local cmd_cut=$(locate_cmd "cut")
  local cmd_sed=$(locate_cmd "sed")
  local cmd_cd=$(locate_cmd "cd")
  local cmd_chmod=$(locate_cmd "chmod")
  local cmd_mkdir=$(locate_cmd "mkdir")
  local heplify_base_dir="/opt/heplify-server"
  if [[ ! -d "$heplify_base_dir" ]]; then
  	$cmd_mkdir -p "$heplify_base_dir"
  fi
  $cmd_cd $heplify_base_dir
  LATEST_RELEASE="$cmd_curl -s https://github.com/sipcapture/heplify-server/releases/latest | $cmd_grep \"releases/tag\""
  DOWNLOAD_URL="$($LATEST_RELEASE | $cmd_cut -d '"' -f 2 | $cmd_sed -e 's/tag/download/g')"
  $cmd_wget "$DOWNLOAD_URL/heplify-server"
  `$cmd_chmod +x "$heplify_base_dir/heplify-server"`
  $cmd_wget https://raw.githubusercontent.com/sipcapture/heplify-server/master/example/homer7_config/heplify-server.toml
  $cmd_sed -i -e "s/DBUser\s*=\s*\"postgres\"/DBUser          = \"$DB_USER\"/g" heplify-server.toml
  $cmd_sed -i -e "s/DBPass\s*=\s*\"\"/DBPass          = \"$DB_PASS\"/g" heplify-server.toml
  $cmd_sed -i -e "s/PromAddr\s*=\s*\"\"/PromAddr        = \"0.0.0.0:9096\"/g" heplify-server.toml
  create_heplify_service
}


banner_start() {
  # This is the banner displayed at the start of script execution

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
}

banner_end() {
  # This is the banner displayed at the end of script execution

  local cmd_ip=$(locate_cmd "ip")
  local cmd_head=$(locate_cmd "head")
  local cmd_awk=$(locate_cmd "awk")

  local my_primary_ip=$($cmd_ip route get 8.8.8.8 | $cmd_head -1 | $cmd_awk '{ print $NF }')

  echo "*************************************************************"
  echo "      ,;;;;,                                                 "
  echo "     ;;;;;;;;.     Congratulations! HOMER has been installed!"
  echo "   ;;;;;;;;;;;;                                              "
  echo "  ;;;;  ;;  ;;;;   <--------------- INVITE ---------------   "
  echo "  ;;;;  ;;  ;;;;    --------------- 200 OK --------------->  "
  echo "  ;;;;  ..  ;;;;                                             "
  echo "  ;;;;      ;;;;   Your system should be now ready to rock!"
  echo "  ;;;;  ;;  ;;;;   Please verify/complete the configuration  "
  echo "  ,;;;  ;;  ;;;;   files generated by the installer below.   "
  echo "   ;;;;;;;;;;;;                                              "
  echo "    :;;;;;;;;;     THIS SCRIPT IS PROVIDED AS-IS, USE AT     "
  echo "     ;;;;;;;;      YOUR *OWN* RISK, REVIEW LICENSE & DOCS    "
  echo "                                                             "
  echo "*************************************************************"
  echo
  echo "     * Configuration Files:"
  echo "         '/usr/local/homer/webapp_config.json'"
  echo "         '/opt/heplify-server/heplify-server.toml'"
  echo
  echo "     * Start/stop HOMER Application Server:"
  echo "         'systemctl start|stop homer-app'"
  echo
  echo "     * Start/stop HOMER SIP Capture Server:"
  echo "         'systemctl start|stop heplify-server'"
  echo
  echo "     * Start/stop HOMER SIP Capture Agent:"
  echo "         'systemctl start|stop heplify'"
  echo
  echo "     * Access HOMER UI:"
  echo "         http://$my_primary_ip:9080"
  echo "         [default: admin/sipcapture]"
  echo
  echo "     * Send HEP/EEP Encapsulated Packets to:"
  echo "         hep://$my_primary_ip:$LISTEN_PORT"
  echo
  echo "     * Prometheus Metrics URL:"
  echo "         http://$my_primary_ip:9096/metrics"
  echo
  if [[ "$INSTALL_INFLUXDB" =~ y|yes|Y|Yes|YES ]] ; then
    echo "     * Access InfluxDB UI:"
    echo "         http://$my_primary_ip:$CHRONOGRAF_LISTEN_PORT"
    echo 
  fi
  echo
  echo "**************************************************************"
  echo
  echo " IMPORTANT: Do not forget to send Homer node some traffic! ;) "
  echo " For our capture agents, visit http://github.com/sipcapture "
  echo " For more help and information visit: http://sipcapture.org "
  echo
  echo "**************************************************************"
  echo " Installer Log saved to: $logfile "
  echo
}

start_app() {
  # This is the main app

  banner_start

  if ! is_root_user; then
    echo "ERROR: You must be the root user. Exiting..." 2>&1
    echo  2>&1
    exit 1
  fi

  if ! is_supported_os "$OSTYPE"; then
    echo "ERROR:"
    echo "Sorry, this Installer does not support your OS yet!"
    echo "Please follow instructions in the HOW-TO for manual installation & setup"
    echo "available at http://sipcapture.org"
    echo
    exit 1
  else
    unalias cp 2>/dev/null
    $SETUP_ENTRYPOINT
    banner_end
  fi
  exit 0
}

create_postgres_user_database(){
  cwd=$(pwd)
  cd /tmp
  sudo -u postgres psql -c "CREATE DATABASE homer_config;"
  sudo -u postgres psql -c "CREATE DATABASE homer_data;"
  sudo -u postgres psql -c "CREATE ROLE ${DB_USER} WITH SUPERUSER LOGIN PASSWORD '$DB_PASS';"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE homer_config to homer_user;"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE homer_data to homer_user;"
  cd $cwd
}

install_heplify_server(){
  PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/usr/local/go/bin  
  local cmd_go=$(locate_cmd "go")
  local cmd_cp=$(locate_cmd "cp")
  local cmd_sed=$(locate_cmd "sed")
  local cmd_cd=$(locate_cmd "cd")
  local src_base_dir="/opt/"
  local src_heplify_dir="heplify-server"
  repo_clone_or_update "$src_base_dir" "$src_heplify_dir" "https://github.com/sipcapture/heplify-server"

  $cmd_cd "$src_base_dir/$src_heplify_dir/"
  $cmd_cp -f "$src_base_dir/$src_heplify_dir/example/homer7_config/heplify-server.toml" "./"
  $cmd_sed -i -e "s/DBUser\s*=\s*\"postgres\"/DBUser          = \"$DB_USER\"/g" heplify-server.toml
  $cmd_sed -i -e "s/DBPass\s*=\s*\"\"/DBPass          = \"$DB_PASS\"/g" heplify-server.toml
  $cmd_sed -i -e "s/PromAddr\s*=\s*\"\"/PromAddr        = \"0.0.0.0:9096\"/g" heplify-server.toml
  $cmd_go build "cmd/heplify-server/heplify-server.go"
  create_heplify_service
}

install_homer_app(){
  local cmd_curl=$(locate_cmd "curl")
  local cmd_wget=$(locate_cmd "wget")
  local cmd_grep=$(locate_cmd "grep")
  local cmd_cut=$(locate_cmd "cut")
  local cmd_sed=$(locate_cmd "sed")
  local cmd_cd=$(locate_cmd "cd")
  local cmd_mkdir=$(locate_cmd "mkdir")
  local homer_source_dir="/usr/src/"
  if [[ ! -d "$homer_source_dir" ]]; then
        $cmd_mkdir -p "$homer_source_dir"
  fi
  
  $cmd_cd $heplify_source_dir
  echo "Installing Homer-App"
  LATEST_RELEASE="$cmd_curl -s https://github.com/sipcapture/homer-app/releases/latest | $cmd_grep \"releases/tag\""
  DOWNLOAD_URL="$($LATEST_RELEASE | $cmd_cut -d '"' -f 2 | $cmd_sed -e 's/tag/download/g')"
  RELEASE_NUMBER=${DOWNLOAD_URL##*/}
  if [ -f /etc/debian_version ]; then
  	local cmd_dpkg=$(locate_cmd "dpkg")
  	COMPLETE_URL="${DOWNLOAD_URL}/homer-app-${RELEASE_NUMBER}-amd64.deb"
  	$cmd_wget $COMPLETE_URL
  	$cmd_dpkg -i "homer-app-${RELEASE_NUMBER}-amd64.deb" 
  else
  	local cmd_rpm=$(locate_cmd "rpm")
  	COMPLETE_URL="${DOWNLOAD_URL}/homer-app-${RELEASE_NUMBER}-amd64.rpm"
  	$cmd_wget $COMPLETE_URL
  	$cmd_rpm -i "homer-app-${RELEASE_NUMBER}-amd64.rpm" 
  fi

  sed -i -e "s/homer_user/$DB_USER/g" /usr/local/homer/etc/webapp_config.json
  sed -i -e "s/homer_password/$DB_PASS/g" /usr/local/homer/etc/webapp_config.json
  local cmd_homerapp=$(locate_cmd "homer-app")
  $cmd_homerapp -create-table-db-config 
  $cmd_homerapp -populate-table-db-config
  sudo systemctl enable homer-app
  sudo systemctl restart homer-app
  sudo systemctl status homer-app

}

setup_influxdb(){

if [ -f /etc/redhat-release ]; then
    echo "RPM Platform detected!"

cat <<EOF | sudo tee /etc/yum.repos.d/influxdb.repo
[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key
EOF

    echo "Installing TICK stack ..."
    sudo yum -y install influxdb kapacitor telegraf chronograf

    yes | cp $CURRENT_DIR/telegraf.conf /etc/telegraf/telegraf.conf

    sudo systemctl start telegraf
    sudo systemctl start influxdb
    sudo systemctl start kapacitor
    sudo systemctl start chronograf

    sudo systemctl enable telegraf
    sudo systemctl enable influxdb
    sudo systemctl enable kapacitor
    sudo systemctl enable chronograf

    sudo systemctl restart telegraf
    echo "done!"

fi

if [ -f /etc/debian_version ]; then

    echo "DEBIAN Platform detected!"

    sudo apt-get install -y apt-transport-https
    curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
    source /etc/os-release
    test $VERSION_ID = "9" && echo "deb https://repos.influxdata.com/debian stretch stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

    echo "Installing TICK stack ..."
    sudo apt-get update && sudo apt-get install -y influxdb kapacitor chronograf

    yes | cp $CURRENT_DIR/telegraf.conf /etc/telegraf/telegraf.conf

    sudo systemctl start telegraf
    sudo systemctl start influxdb
    sudo systemctl start kapacitor
    sudo systemctl start chronograf

    sudo systemctl enable influxdb
    sudo systemctl enable kapacitor
    sudo systemctl enable chronograf

    sudo systemctl restart telegraf
    echo "done!"

fi

}


setup_centos_7() {
  # This is the main entrypoint for setup of sipcapture/homer on a CentOS 7
  # system

  local base_pkg_list="wget curl mlocate make cmake gcc gcc-c++ ntp yum-utils net-tools epel-release htop vim openssl"
  local src_base_dir="/usr/src"

  local cmd_yum=$(locate_cmd "yum")
  local cmd_wget=$(locate_cmd "wget")
  local cmd_service=$(locate_cmd "systemctl")
  local cmd_curl=$(locate_cmd "curl")
  local cmd_sed=$(locate_cmd "sed")
  local cmd_iptables=$(locate_cmd "iptables")
  local cmd_rpm=$(locate_cmd "rpm")
  
  $cmd_yum -y update && $cmd_yum -y upgrade  
  $cmd_yum install -y $base_pkg_list

  #disable SELinux
  echo "Disabling SELinux"
  echo "Reboot required after installation completes"
  setenforce 0
  sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config

  $cmd_yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
  $cmd_yum install -y postgresql12-server postgresql12
  #lets find the file to initialize the service
  updatedb
  local cmd_locatepostgre="$(locate postgresql-12-setup)"
  $cmd_locatepostgre initdb
  $cmd_sed -i 's/\(host  *all  *all  *127.0.0.1\/32  *\)ident/\1md5/' /var/lib/pgsql/12/data/pg_hba.conf
  $cmd_sed -i 's/\(host  *all  *all  *::1\/128  *\)ident/\1md5/' /var/lib/pgsql/12/data/pg_hba.conf
  $cmd_service daemon-reload
  $cmd_service enable postgresql-12
  $cmd_service restart postgresql-12
  create_postgres_user_database
  echo "Press [y/Y] to install heplify-server binary and [n/N] to install from source(Golang would be installed)"
  printf "default use binary: "
  read HEPLIFY_MEHTHOD
  case "$HEPLIFY_MEHTHOD" in
          "y"|"yes"|"Y"|"Yes"|"YES") setup_heplify_server;;
          "n"|"no"|"N"|"No"|"NO") install_golang;;
          *) setup_heplify_server;;
  esac
  install_homer_app

  echo "Configuring FirewallD"

  #configure the firewall
  firewall-cmd --permanent --zone=public --add-port=9080/udp
  firewall-cmd --permanent --zone=public --add-port=9080/tcp
  firewall-cmd --permanent --zone=public --add-port={9060,9096,8086,8888}/udp
  firewall-cmd --permanent --zone=public --add-port={9060,9096,8086,8888}/tcp
  firewall-cmd --reload
  echo "FirewallD configured"

  printf "Would you like to install influxdb and chronograf? [y/N]: "
  read INSTALL_INFLUXDB
  case "$INSTALL_INFLUXDB" in
          "y"|"yes"|"Y"|"Yes"|"YES") setup_influxdb;;
          *) echo "...... [ Exiting ]"; echo;;
  esac
}

setup_debian_9() {
  local base_pkg_list="software-properties-common make cmake gcc g++ dirmngr sudo python3-dev"
  local src_base_dir="/usr/src"
  local cmd_apt_get=$(locate_cmd "apt-get")
  local cmd_wget=$(locate_cmd "wget")
  local cmd_apt_key=$(locate_cmd "apt-key")
  local cmd_service=$(locate_cmd "systemctl")
  local cmd_curl=$(locate_cmd "curl")
  local cmd_rm=$(locate_cmd "rm")
  local cmd_ln=$(locate_cmd "ln")
  local cmd_wget=$(locate_cmd "wget")

  $cmd_apt_get update && $cmd_apt_get upgrade -y

  $cmd_apt_get install -y $base_pkg_list

  $cmd_wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O- | sudo $cmd_apt_key add -

  echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" > /etc/apt/sources.list.d/postgresql.list

  $cmd_apt_get update
  
  $cmd_apt_get install -y postgresql-12
  
  $cmd_service daemon-reload
  $cmd_service enable postgresql
  $cmd_service restart postgresql

  create_postgres_user_database
  echo "Press [y/Y] to install heplify-server binary and [n/N] to install from source(Golang would be installed)"
  printf "default use binary: "
  read HEPLIFY_MEHTHOD 
  case "$HEPLIFY_MEHTHOD" in 
          "y"|"yes"|"Y"|"Yes"|"YES") setup_heplify_server;;
          "n"|"no"|"N"|"No"|"NO") install_golang;;
          *) setup_heplify_server;;
  esac
  install_homer_app
  printf "Would you like to install influxdb and chronograf? [y/N]: "
  read INSTALL_INFLUXDB 
  case "$INSTALL_INFLUXDB" in 
          "y"|"yes"|"Y"|"Yes"|"YES") setup_influxdb;;
          *) echo "...... [ Exiting ]"; echo;;
  esac
}

######################################################################
#
# End of function definitions
#
######################################################################

######################################################################
#
# Start of main script
#
######################################################################

[[ "$0" == "$BASH_SOURCE" ]] && start_app
