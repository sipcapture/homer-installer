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

[[ "$TRACE" ]] && { set -x; set -o functrace; }

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

logfile="/tmp/$(basename $0).$$.log"
exec > >(tee -ia $logfile)
exec 2> >(tee -ia $logfile >&2)

trap 'exit 1' TERM
my_pid=$$


# HOMER Options, defaults
DB_USER="homer_user"
DB_PASS="homer_password"
DB_HOST="localhost"
LISTEN_PORT="9060"

#### NO CHANGES BELOW THIS LINE! 

DB_ADMIN_USER="root"
DB_ADMIN_PASS=""
DB_ADMIN_TEMP_PASS=""

VERSION=5.0.5
SETUP_ENTRYPOINT=""
OS=""
DISTRO=""
DISTRO_VERSION=""
WEB_ROOT=""

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
             minimal_command_list="lsb_release"
						 package_list="redhat-lsb-core"
             if ! have_commands "$minimal_command_list"; then
               echo "ERROR: You need the following minimal set of commands installed:"
               echo ""
               echo "       $package_list"
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
               8* ) SETUP_ENTRYPOINT="setup_debian_8"
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

create_or_update_dir() {
  # This function essentially copies the homer ui/api from
  # their source directory to their destination directory
  # and sets the proper ownerships once done

  local src_dir="$1"
  local dst_dir="$2"

  local cmd_find=$(locate_cmd "find")
  local cmd_mkdir=$(locate_cmd "mkdir")
  local cmd_chown=$(locate_cmd "chown")
  local cmd_cpio=$(locate_cmd "cpio")

  if [ ! -d "$dst_dir" ]; then
    $cmd_mkdir -p -m 0755 "$dst_dir"
    check_status "$?"
    $cmd_chown "$web_ownership" "$dst_dir"
    check_status "$?"
  fi

  if [ ! -d "$src_dir" ]; then
    echo "ERROR: Source directory '$src_dir' not found, aborting."
    echo "Please check the log above and correct the issue."
    exit 1
  fi

  cd "$src_dir"
  $cmd_find . -depth -print | $cmd_cpio -dump "$dst_dir"/
  check_status "$?"
  $cmd_chown -R "$web_ownership" "$dst_dir"/
  check_status "$?"
}

create_or_update_maintenance_scripts() {
  # This function copies the sipcapture maintenance scripts to
  # the homer maintenance scripts directory

  local src_dir="$1"
  local dst_dir="$2"
  local db_type="$3"

  local cmd_mkdir=$(locate_cmd "mkdir")
  local cmd_chmod=$(locate_cmd "chmod")
  local cmd_cp=$(locate_cmd "cp")
  local cmd_ln=$(locate_cmd "ln")

  if [[ ! -d "$dst_dir" ]]; then
    $cmd_mkdir -p -m 0755 "$dst_dir"
    check_status "$?"
  fi

  $cmd_cp $src_dir/"$db_type"/* "$dst_dir"/.
  check_status "$?"
  $cmd_ln -f -r -s "$dst_dir/homer_${db_type}_rotate" "$dst_dir/homer_rotate"
  check_status "$?"
}

create_or_update_misc() {
  # This function sets the ownerships/permissions of some required directories,
  # It also ensures these directories exists beforhand

  local -a web_dirs=(
                     "0755|$web_doc_root/store" \
                     "0755|$web_doc_root/store/dashboard" \
                     "0777|$web_doc_root/api/tmp"
                    )

  local cmd_mkdir=$(locate_cmd "mkdir")
  local cmd_chown=$(locate_cmd "chown")

  local original_ifs=$IFS
  IFS=$'|'
  for details in "${web_dirs[@]}"; do
    read -r perms dir <<< "$details"
    if [[ ! -d "$dir" ]]; then
      $cmd_mkdir -p -m "$perms" "$dir"
      $cmd_chown "$web_ownership" "$dir"
    else
      $cmd_chown "$web_ownership" "$dir"
    fi
  done
  IFS=$original_ifs
}

create_or_update_config() {
  # This function copies the default configuration files for homer and opensips into place

  local opensips_version=${1:-"2"}
  local overwrite_dst=${2:-"yes"}
  local -a cfg_files=(
                       "$src_base_dir/$src_homer_config_dir/docker/configuration.php|$web_doc_root/api/configuration.php" \
                       "$src_base_dir/$src_homer_config_dir/docker/preferences.php|$web_doc_root/api/preferences.php" \
                       "$src_base_dir/$src_homer_config_dir/docker/vhost.conf|$web_cfg_root/sipcapture.conf" \
                     )

  cmd_cp=$(locate_cmd "cp")
  cmd_chmod=$(locate_cmd "chmod")

  case "$opensips_version" in
    2 ) cfg_files+=("${cfg_files[@]}" "/usr/src/homer-config/sipcapture/sipcapture.opensips23|/etc/opensips/opensips.cfg") ;;
  esac

  local original_ifs=$IFS
  IFS=$'|'
  for cfg in "${cfg_files[@]}"; do
    read -r src dst <<< "$cfg"
    if [[ ! -e "$dst" ]] && [[ ! -L "$dst" ]]; then
      $cmd_cp "$src" "$dst"
      check_status "$?"
      $cmd_chmod 0644 "$dst"
      check_status "$?"
    else
      if [[ "$overwrite_dst" == "yes" ]]; then
        $cmd_cp -f "$src" "$dst"
        check_status "$?"
        $cmd_chmod 0644 "$dst"
        check_status "$?"
      fi
    fi
  done
  IFS=$original_ifs
}

create_or_update_cron() {
  # This function updates the crontab entry for the current user

  local cron_log="${1:-/var/log/cron.log}"

  local cmd_crontab=$(locate_cmd "crontab")
  local cmd_sort=$(locate_cmd "sort")
  local cmd_uniq=$(locate_cmd "uniq")

  ( 
    $cmd_crontab -l; \
    echo "30 3 * * * $mnt_script_dir/homer_rotate >> $cron_log 2>&1"
  ) \
  | $cmd_sort - \
  | $cmd_uniq - \
  | $cmd_crontab -
  check_status "$?"
}

get_mysql_details() {
  # This function asks the user for the user/host details for the database

  local mysql_log_file="${2:-/var/log/mysqld.log}"
  local sql_root_pass=""

  local cmd_date=$(locate_cmd "date")
  local cmd_shasum=$(locate_cmd "sha256sum")
  local cmd_base64=$(locate_cmd "base64")
  local cmd_head=$(locate_cmd "head")
  local cmd_awk=$(locate_cmd "awk")
  local cmd_chown=$(locate_cmd "chown")
  local cmd_chmod=$(locate_cmd "chmod")

  local confirmed="no"
  local sql_homer_pass=$($cmd_date +%s | $cmd_shasum | $cmd_base64 | $cmd_head -c 15)
  sleep 1 # Needed for epoch stamp to change so that homer user and admin user passwords are not the same
  local sql_admin_pass=$($cmd_date +%s | $cmd_shasum | $cmd_base64 | $cmd_head -c 15)

  if [[ -f $mysql_log_file ]]; then
    sql_root_pass=$($cmd_awk '/A temporary password is generated for root/ {print $NF}' $mysql_log_file)
    if [[ -z "$sql_root_pass" ]]; then
      echo "ERROR: Cannot locate temporory root password, aborting."
      echo "       Please check the logs and correct manually"
      exit 1
    fi
    DB_ADMIN_TEMP_PASS=$sql_root_pass
  fi

  while [[ x"$confirmed"x == x"no"x ]]; do
    read -p "Please enter the database hostname for HOMER: [default: '$DB_HOST'] " database_host
    [[ -z "$database_host" ]] && database_host=$DB_HOST

    read -p "Please enter the database username for HOMER: [default: '$DB_USER'] " homer_user_account
    [[ -z "$homer_user_account" ]] && homer_user_account=$DB_USER

    read -p "Please enter the password for HOMER username '$homer_user_account': [default: '$sql_homer_pass'] " homer_user_password
    [[ -z "$homer_user_password" ]] && homer_user_password=$sql_homer_pass

    # read -p "Please enter the database superuser username: [default: '$DB_ADMIN_USER'] " admin_user_account
    # [[ -z "$admin_user_account" ]] && admin_user_account=$DB_ADMIN_USER

    # read -p "Please enter the password for database admin user '$DB_ADMIN_USER': " admin_user_password
    # [[ -z "$admin_user_password" ]] && admin_user_password=$sql_root_pass

    echo ""
    echo "  Database Host : $database_host"
    echo ""
    echo "  Homer Username: $homer_user_account"
    echo "  Homer Password: $homer_user_password"
    # echo "  Admin Username: $DB_ADMIN_USER"
    # echo "  Admin Password: $sql_admin_pass"
    echo ""
    read -p "Please confirm the above details are correct [Y/n]" confirmation

    [[ -z "$confirmation" ]] && confirmation="y"
    [[ x"$confirmation"x == x"y"x ]] && confirmed="yes"
  done

  DB_HOST=$database_host
  DB_USER=$homer_user_account
  DB_PASS=$homer_user_password
  # DB_ADMIN_USER=$admin_user_account
  DB_ADMIN_PASS=$sql_admin_pass

  (
    echo "Mysql Homer Username: $DB_USER"
    echo "Mysql Homer Password: $DB_PASS"
    echo "Mysql Admin Username: $DB_ADMIN_USER"
    echo "Mysql Admin Password: $DB_ADMIN_PASS (Set by installer)"
    [[ ! -z "$DB_ADMIN_TEMP_PASS" ]] && echo "Mysql Admin Temp Password: $DB_ADMIN_TEMP_PASS (Automatically generated by MySQL)"
    echo "Mysql Database Host : $DB_HOST"
  ) > ~root/homer_installer_user_details
  $cmd_chmod 0600 ~/homer_installer_user_details
  $cmd_chown root:root ~/homer_installer_user_details
}

mysql_ready() {
  # This function checks to see if mysql is running and accepting connections

  local use_password="${1:-yes}"
  local connect_timeout="${2:-3}"
  local retries="${3:-3}"
  local tries=1
  local sleep_time=2
  local mysql_params="--user=$DB_ADMIN_USER --host=$DB_HOST --silent --connect-timeout=$connect_timeout"

  local cmd_mysqladmin=$(locate_cmd "mysqladmin")
  local cmd_sleep=$(locate_cmd "sleep")

  if [[ x"$use_password"x == x"yes"x ]]; then
    mysql_params="$mysql_params --password=$DB_ADMIN_TEMP_PASS"
  fi

  while [[ "$tries" -le "$retries" ]]; do
    $cmd_mysqladmin $mysql_params ping 2>/dev/null

    if [[ $? == 0 ]]; then
      return 0
    fi

    $cmd_sleep "$sleep_time"
    tries=$((tries + 1))
  done

  return 1
}

mysql_secure() {
  # This function sets the database superuser password to that of the password given
  # by the user in a previous step, it then goes and "secures" mysql in a similar 
  # fashion to that of "mysql_secure_installtion"

  local use_password="${1:-yes}"
  local mysql_params="--user=$DB_ADMIN_USER --host=$DB_HOST"
  local -a mysql_cmds=(
                        "UPDATE mysql.user SET authentication_string=PASSWORD('$DB_ADMIN_PASS') WHERE User='$DB_ADMIN_USER';" \
                        "DELETE FROM mysql.user WHERE User='$DB_ADMIN_USER' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" \
                        "DELETE FROM mysql.user WHERE User='';" \
                        "DROP DATABASE IF EXISTS test;" \
                        "FLUSH PRIVILEGES;"
                      )

  local cmd_mysql=$(locate_cmd "mysql")

  if [[ x"$use_password"x == x"yes"x ]]; then
    $cmd_mysql $mysql_params --password="$DB_ADMIN_TEMP_PASS" --connect-expired-password -e \
      "SET GLOBAL validate_password_policy=LOW; ALTER USER USER() IDENTIFIED BY '$DB_ADMIN_PASS';"
    check_status "$?"
  else
    $cmd_mysql $mysql_params -e \
      "ALTER USER USER() IDENTIFIED BY '$DB_ADMIN_PASS';"
    check_status "$?"
  fi

  for cmd in "${mysql_cmds[@]}"; do
    $cmd_mysql $mysql_params --password="$DB_ADMIN_PASS" -e "$cmd"
    check_status "$?"
  done
}

mysql_load() {
  # This function creates the homer user and then loads the default data
  # into the database

  local mysql_ddl_dir="${1:-$src_base_dir/$src_homer_api_dir/sql/mysql}"
  local mysql_data_dir="${2:-/var/lib/mysql}"
  local lower_mysql_pass_validation="${3:-no}"
  local -a mysql_ddl=(
                       "|$mysql_ddl_dir/homer_databases.sql" \
                       "homer_data|$mysql_ddl_dir/schema_data.sql" \
                       "homer_configuration|$mysql_ddl_dir/schema_configuration.sql" \
                       "homer_statistic|$mysql_ddl_dir/schema_statistic.sql"
                     )

  local cmd_printf=$(locate_cmd "printf")
  local cmd_chown=$(locate_cmd "chown")
  local cmd_chmod=$(locate_cmd "chmod")
  local cmd_sed=$(locate_cmd "sed")
  local cmd_mysql=$(locate_cmd "mysql")

  if [[ x"$lower_mysql_pass_validation"x == x"yes"x ]]; then
    $cmd_mysql --user="$DB_ADMIN_USER" --password="$DB_ADMIN_PASS" -e \
      "SET GLOBAL validate_password_policy=LOW;"
    check_status "$?"
    echo "validate_password_policy=LOW" >> /etc/my.cnf
  fi

  $cmd_mysql --user="$DB_ADMIN_USER" --password="$DB_ADMIN_PASS" -e \
    "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;"
  check_status "$?"

  # Fixup passwords to get rid of mysql low policy errors
  $cmd_sed -i -e "s/test123/test1234/g" -e "s/123test/1234test/g" $mysql_ddl_dir/schema_configuration.sql

  local original_ifs=$IFS
  IFS=$'|'
  for db_ddl in "${mysql_ddl[@]}"; do
    read -r db ddl <<< "$db_ddl"
    $cmd_mysql --user="$DB_USER" --password="$DB_PASS" "$db" < "$ddl"
    check_status "$?"
  done
  IFS=$original_ifs

  $cmd_mysql --user="$DB_USER" --password="$DB_PASS" homer_configuration -e \
    "DELETE FROM node;"
  check_status "$?"

  $cmd_mysql --user="$DB_USER" --password="$DB_PASS" homer_configuration -e \
    "ALTER TABLE node AUTO_INCREMENT = 1;"
  check_status "$?"

  $cmd_mysql --user="$DB_USER" --password="$DB_PASS" homer_configuration -e \
    "INSERT INTO node VALUES(default,'$DB_HOST','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"
  check_status "$?"

  echo "Homer initial data load complete" > "$mysql_data_dir/.homer_initialized"

}

config_search_and_replace() {
  # This function updates the configuration files to reflect the correct
  # user details for connecting to the database by the apps. It also updates
  # supporting confirguration files for custom settings.

  local cmd_sed=$(locate_cmd "sed")

  # Maintenance Scripts
  $cmd_sed -i \
    -e "s/homer_user/$DB_USER/g" \
    -e "s/homer_password/$DB_PASS/g" \
    "$mnt_script_dir/rotation.ini" \
    "$mnt_script_dir/homer_rotate"

  # Homer configuration
  $cmd_sed -i \
    -e "s/{{ DB_USER }}/$DB_USER/g" \
    -e "s/{{ DB_PASS }}/$DB_PASS/g" \
    -e "s/{{ DB_HOST }}/$DB_HOST/g" \
    "$web_doc_root/api/configuration.php"

  # OpenSIPS Scripts
  $cmd_sed -i \
    -e "s/{{ DB_USER }}/$DB_USER/g" \
    -e "s/{{ DB_PASS }}/$DB_PASS/g" \
    -e "s/{{ DB_HOST }}/$DB_HOST/g" \
    -e "s/9060/$LISTEN_PORT/g" \
    /etc/opensips/opensips.cfg

  # Apache docroot
  $cmd_sed -i \
    -e "s|^\(.*DocumentRoot\).*|\1 $web_doc_root|g" \
    $web_cfg_root/sipcapture.conf
}

create_opensips_service() {
  local sys_systemd_base='/lib/systemd/system'
  local usr_systemd_base='/etc/systemd/system'
  local sys_opensips_svc='opensips.service'
  local sys_mysql_svc=''

  local cmd_systemctl=$(locate_cmd "systemctl")
  local cmd_cat=$(locate_cmd "cat")
  local cmd_mkdir=$(locate_cmd "mkdir")
  
  if [ -d $sys_systemd_base ]; then
    if [ -f $sys_systemd_base/mysql.service ]; then
      sys_mysql_svc=mysql.service
    elif [ -f $sys_systemd_base/mysqld.service ]; then
      sys_mysql_svc=mysqld.service
    fi

    if [ ! -f $sys_systemd_base/$sys_opensips_svc ]; then
      $cmd_cat << __EOFL__ > $sys_systemd_base/$sys_opensips_svc
[Unit]
Description=OpenSIPS (OpenSER) - the Open Source SIP Server
After=network.target

[Service]
Type=forking
Environment='CFGFILE=/etc/opensips/opensips.cfg'
Environment='SHM_MEMORY=64'
Environment='PKG_MEMORY=8'
Environment='USER=opensips'
Environment='GROUP=opensips'
EnvironmentFile=-/etc/default/opensips
EnvironmentFile=-/etc/default/opensips.d/*
# PIDFile requires a full absolute path
PIDFile=/var/run/opensips/opensips.pid
# ExecStart requires a full absolute path
ExecStart=/usr/sbin/opensips -P /var/run/opensips/opensips.pid -f \$CFGFILE -m \$SHM_MEMORY -M \$PKG_MEMORY -u \$USER -g \$GROUP
Restart=on-abort

[Install]
WantedBy=multi-user.target
__EOFL__
      check_status "$?"
    fi  
    if [ ! -d $usr_systemd_base/${sys_opensips_svc}.d ]; then
      $cmd_mkdir -m 0755 -p $usr_systemd_base/${sys_opensips_svc}.d
      check_status "$?"
    fi
    if [ ! -f $usr_systemd_base/${sys_opensips_svc}.d/require_mysql.conf ] && \
       [ ! -z "$sys_mysql_svc" ]; then
      $cmd_cat << __EOFL__ > $usr_systemd_base/${sys_opensips_svc}.d/require_mysql.conf
[Unit]
After= $sys_mysql_svc
__EOFL__
      check_status "$?"
    fi
    $cmd_systemctl daemon-reload    
    check_status "$?"
  fi
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
  local cmd_cut=$(locate_cmd "cut")

  local my_primary_ip=$($cmd_ip route get 8.8.8.8 | $cmd_head -1 | $cmd_cut -d' ' -f8)

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
  echo "     * Verify configuration for HOMER-API:"
  echo "         '$WEB_ROOT/api/configuration.php'"
  echo "         '$WEB_ROOT/api/preferences.php'"
  echo
  echo "     * Verify capture settings for Homer/OpenSIPS:"
  echo "         '/etc/opensips/opensips.cfg'"
  echo
  echo "     * Start/stop Homer SIP Capture:"
  echo "         '/sbin/opensipsctl start|stop'"
  echo
  echo "     * Access HOMER UI:"
  echo "         http://$my_primary_ip"
  echo "         [default: admin/test1234]"
  echo
  echo "     * Send HEP/EEP Encapsulated Packets:"
  echo "         hep://$my_primary_ip:$LISTEN_PORT"
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

setup_centos_7() {
  # This is the main entrypoint for setup of sipcapture/homer on a CentOS 7
  # system

  local base_pkg_list="wget autoconf automake bzip2 cpio curl curl-devel \
                       expat-devel fileutils make gcc gcc-c++ gettext-devel \
                       gnutls-devel openssl openssl-devel mod_ssl perl patch rsyslog \
                       unzip zip zlib zlib-devel bison flex pcre-devel libxml2-devel \
                       sox httpd php php-gd php-mysql php-json git php-mysql php-devel"
  local opensips_pkg_list="opensips opensips-geoip-module opensips-json-module \
                           opensips-mysql-module opensips-regex-module opensips-restclient-module"
  local mysql_pkg_list="libdbi-dbd-mysql perl-DBD-MySQL mysql-community-server mysql-community-client"
  local -a service_names=("mysqld" "opensips" "httpd")
  local web_cfg_root="/etc/httpd/conf.d"
  local web_doc_root="/var/www/html/homer"
  WEB_ROOT=$web_doc_root # WEB_ROOT used in banner_end function
  local web_ownership="apache:apache"
  local mnt_script_dir="/opt/homer"
  local src_base_dir="/usr/src"
  local src_homer_ui_dir="homer-ui"
  local src_homer_api_dir="homer-api"
  local src_homer_config_dir="homer-config"

  local cmd_yum=$(locate_cmd "yum")
  local cmd_wget=$(locate_cmd "wget")
  local cmd_chkconfig=$(locate_cmd "chkconfig")
  local cmd_service=$(locate_cmd "service")

  $cmd_yum -q -y install "https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm"
  # check_status "$?"

  $cmd_yum -q -y install "http://yum.opensips.org/2.3/releases/el/7/x86_64/opensips-yum-releases-2.3-3.el7.noarch.rpm"

  $cmd_yum clean all; $cmd_yum makecache

  $cmd_yum -y update
  check_status "$?"

  $cmd_yum -y install $base_pkg_list $opensips_pkg_list $mysql_pkg_list
  # check_status "$?"

  create_opensips_service

  for svc in ${service_names[@]}; do
    $cmd_chkconfig "$svc" on
  done

  repo_clone_or_update "$src_base_dir" "$src_homer_api_dir" "https://github.com/sipcapture/homer-api.git"
  repo_clone_or_update "$src_base_dir" "$src_homer_ui_dir" "https://github.com/sipcapture/homer-ui.git"
  repo_clone_or_update "$src_base_dir" "$src_homer_config_dir" "https://github.com/sipcapture/homer-config.git"

  create_or_update_dir "$src_base_dir/$src_homer_ui_dir" "$web_doc_root"
  create_or_update_dir "$src_base_dir/$src_homer_api_dir/api" "$web_doc_root/api"
  create_or_update_maintenance_scripts "$src_base_dir/$src_homer_api_dir/scripts" "$mnt_script_dir" "mysql"
  create_or_update_misc
  create_or_update_config
  create_or_update_cron

  $cmd_service mysqld start
  get_mysql_details

  if ! mysql_ready; then
    echo "ERROR: mysql does not appear to be running and/or available, aborting"
    echo "       please check the logs and correct the issue"
    exit 1
  fi

  mysql_secure
  mysql_load "" "" "yes"

  config_search_and_replace
  $mnt_script_dir/homer_rotate

  for svc in ${service_names[@]}; do
    $cmd_service "$svc" restart
  done
}

setup_debian_8() {
  # This is the main entrypoint for setup of sipcapture/homer on a Debian 8
  # system

  local base_pkg_list="ca-certificates apache2 libapache2-mod-php5 php5 \
                       php5-cli php5-gd php-pear php5-dev php5-mysql php5-json \
                       php-services-json git wget pwgen rsyslog perl libdbi-perl libclass-dbi-mysql-perl"
  local opensips_pkg_list="rsyslog opensips opensips-geoip-module opensips-json-module opensips-mysql-module \
                           opensips-regex-module opensips-restclient-module \
                           geoip-database geoip-database-extra"
  local mysql_pkg_list="mysql-server libmysqlclient18"
  local -a service_names=("mysql" "opensips" "apache2")
  local -a repo_keys=(
                       'opensips23|049AD65B' \
                       'mysql57|8C718D3B5072E1F5'
                     )
  local web_cfg_root="/etc/apache2/sites-available"
  local web_doc_root="/var/www/html/homer"
  WEB_ROOT=$web_doc_root # WEB_ROOT used in banner_end function
  local web_ownership="www-data:www-data"
  local mnt_script_dir="/opt/homer"
  local src_base_dir="/usr/src"
  local src_homer_ui_dir="homer-ui"
  local src_homer_api_dir="homer-api"
  local src_homer_config_dir="homer-config"

  local cmd_apt_get=$(locate_cmd "apt-get")
  local cmd_apt_key=$(locate_cmd "apt-key")
  local cmd_service=$(locate_cmd "service")
  local cmd_rm=$(locate_cmd "rm")
  local cmd_ln=$(locate_cmd "ln")
  local cmd_update_rcd=$(locate_cmd "update-rc.d")

  echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-5.7" > /etc/apt/sources.list.d/mysql.list
  echo "deb http://apt.opensips.org jessie 2.3-releases" > /etc/apt/sources.list.d/opensips23.list

  local original_ifs=$IFS
  IFS=$'|'
  for key_info in "${repo_keys[@]}"; do
    read -r repo key <<< "$key_info"
    $cmd_apt_key adv --recv-keys --keyserver hkp://ha.pool.sks-keyservers.net:80 $key
  done
  IFS=$original_ifs

  $cmd_apt_get update -qq
  DEBIAN_FRONTEND=noninteractive $cmd_apt_get install --no-install-recommends --no-install-suggests -yqq \
    $base_pkg_list $opensips_pkg_list $mysql_pkg_list

  create_opensips_service
  repo_clone_or_update "$src_base_dir" "$src_homer_api_dir" "https://github.com/sipcapture/homer-api.git"
  repo_clone_or_update "$src_base_dir" "$src_homer_ui_dir" "https://github.com/sipcapture/homer-ui.git"
  repo_clone_or_update "$src_base_dir" "$src_homer_config_dir" "https://github.com/sipcapture/homer-config.git"

  create_or_update_dir "$src_base_dir/$src_homer_ui_dir" "$web_doc_root"
  create_or_update_dir "$src_base_dir/$src_homer_api_dir/api" "$web_doc_root/api"
  create_or_update_maintenance_scripts "$src_base_dir/$src_homer_api_dir/scripts" "$mnt_script_dir" "mysql"
  create_or_update_misc
  create_or_update_config
  create_or_update_cron

  if [[ -d /etc/apache2/sites-enabled ]]; then
    $cmd_rm -rf /etc/apache2/sites-enabled/*
    $cmd_ln -s -r $web_cfg_root/sipcapture.conf /etc/apache2/sites-enabled/sipcapture.conf
  fi

  $cmd_service mysql start
  get_mysql_details

  if ! mysql_ready "no"; then
    echo "ERROR: mysql does not appear to be running and available, aborting"
    echo "       please check the logs and correct the issue"
    exit 1
  fi

  mysql_secure "no"
  mysql_load

  config_search_and_replace
  $mnt_script_dir/homer_rotate

  if [[ -d /usr/lib/x86_64-linux-gnu/opensips ]]; then
    if [[ ! -e /usr/lib64 ]]; then
      $cmd_ln -r -f -s /usr/lib /usr/lib64
    fi
    if [[ ! -e /usr/lib64/opensips ]]; then
      $cmd_ln -r -f -s /usr/lib/x86_64-linux-gnu/opensips /usr/lib64/opensips
    fi
  fi

  local cmd_a2enmod=$(locate_cmd "a2enmod")
  $cmd_a2enmod rewrite

  for svc in ${service_names[@]}; do
    $cmd_update_rcd $svc enable
    $cmd_service "$svc" restart
  done
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
