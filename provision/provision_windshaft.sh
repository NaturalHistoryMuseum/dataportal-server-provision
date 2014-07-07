#!/usr/bin/env bash

# Parameters
DEV_MODE=0
DB_HOST=127.0.0.1
DB_USER=datastore_windshaft
DB_PASS=
SYNCED_FOLDER=/vagrant
PROVISION_FILE=/etc/windshaft-provisioned
PROVISION_COUNT=4 # Total number of provision items
PROVISION_FOLDER=
PROVISION_STEP=0
NODE_VERSION=v0.10.15
NPM_VERSION=v1.3.5

#
# usage() function to display script usage
#
function usage(){
  echo "Usage: $0 options

This script provisions a server to host a windshaft server
for providing tiles to a ckan data portal.


OPTIONS:
  -h   Show this message
  -d   Enable development mode. This will:
       - create symlinks in the Vagrant folder ;
       - change the default values for -r
  -p   Postgres password.
       If password is not defined  the script will prompt
       the user for the password.
  -g   Postgres hostname/IP address. Defaults to localhost.
  -v   Synced folder. Defaults to /vagrant. Only used
       in development mode via Vagrant ;
  -r   Path to folder containing provisioning resources.
       In development mode, this defaults to <SYNCED_FOLDER>/provision ;
       In normal mode, this defaults to the path of the current script.
  -x   Set the provision step to run. Note that running this WILL NOT
       UPDATE THE CURRENT PROVISION VERSION. Edit ${PROVISION_FILE}
       manually for this.
"
}


#
# ensure_pass ensures the given variable is filled in with
# a password
#
function ensure_pass(){
  VARNAME=$1
  while [ "${!VARNAME}" = "" ]; do 
    read -s -p "Please enter $2  password: " ${VARNAME}
    echo ""
    read -s -p "Please confirm password: " CONFIRM_PASSWORD 
    echo ""
    if [ "${!VARNAME}" != ${CONFIRM_PASSWORD} ]; then
      echo "Password mismatch."
      eval "${VARNAME}="
    fi
    # Ensure the password is safe for queries
    echo "${!VARNAME}" | grep -q '^[-_+*0-9a-zA-Z]*$'
    if [ $? -ne 0 ]; then
      echo "Only -_+*0-9a-zA-Z allowed in password."
      eval "${VARNAME}="
    fi
  done
}

#
# Read options
#
while getopts "hdg:p:x:r:" OPTION; do
  case $OPTION in
    h)
      usage
      exit 0
      ;;
    d)
      DEV_MODE=1
      ;;
    p)
      DB_PASS=$OPTARG
      ;;
    g)
      DB_HOST=$OPTARG
      ;;
    v)
      SYNCED_FOLDER=$OPTARG
      ;;
    r)
      PROVISION_FOLDER=$OPTARG
      ;;
    x)
      PROVISION_STEP=$OPTARG
      ;;
    ?)
      usage
      exit 0
      ;;
  esac
done
# Set the default provision folder
if [ "${PROVISION_FOLDER}" = "" ]; then
  if [ ${DEV_MODE} -eq 1 ]; then
    PROVISION_FOLDER="${SYNCED_FOLDER}/provision"
  else
    PROVISION_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  fi
fi
ensure_pass DB_PASS

#
# Initial provision, step 1: install nodejs, npm and redis
#
function provision_1(){
  apt-get update
  apt-get install -y build-essential
  mkdir ~/build
  cd ~/build
  git clone git://github.com/joyent/node.git  
  cd node
  git checkout tags/${NODE_VERSION}
  ./configure --prefix=/usr/local
  make install
  cd ..
  git clone git://github.com/isaacs/npm.git
  cd npm
  git checkout tags/${NPM_VERSION}
  make install
  apt-get install -y redis-server
}

#
# Initial provision, step 2: install mapnik
#
function provision_2(){
  if [ ! -f "${PROVISION_FOLDER}/mapnik.list" ]; then
    echo "Missing file ${PROVISION_FOLDER}/mapnik.list ; aborting." 1>&2
    exit 1
  fi

  echo "Installing mapnik"
  cp "${PROVISION_FOLDER}/mapnik.list" /etc/apt/sources.list.d/
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F7B93595D50B6BA 
  apt-get update
  apt-get install -y libmapnik libmapnik-dev mapnik-utils python-mapnik
}

#
# Initial provision, step 3: install windshaft
#
function provision_3(){
  if [ ${DEV_MODE} -eq 1 ]; then
    echo "Setting up symlinks"
    mkdir -p "${SYNCED_FOLDER}/www"
    [ -d /var/www ] && mv /var/www /var/www.bak
    ln -fs "${SYNCED_FOLDER}/www" /var/www
  else
    mkdir -p /var/www
  fi

  [ -d /var/www/nhm-windshaft ] && mv /var/www/nhm-windshaft /var/www/nhm-windshaft.$(date +"%F-%T")
  git clone git://github.com/NaturalHistoryMuseum/nhm-windshaft-app.git /var/www/nhm-windshaft
  chown -R www-data:www-data /var/www/nhm-windshaft
  cd /var/www/nhm-windshaft
  npm install
}

#
# Initial provision, step 4: add config file
#
function provision_4(){
  cat "$PROVISION_FOLDER/config.js" | sed -e "s~%DB_HOST%~$DB_HOST~"  -e "s~%DB_USER%~$DB_USER~" -e "s~%DB_PASS%~$DB_PASS~" > /var/www/nhm-windshaft/config.js
}

#
# Work out current version and apply the appropriate provisioning script.
#
if [ ! -f ${PROVISION_FILE} ]; then
  PROVISION_VERSION=0
else
  PROVISION_VERSION=`cat ${PROVISION_FILE}`
fi
if [ "${PROVISION_STEP}" -ne 0 ]; then
  eval "provision_${PROVISION_STEP}"
elif [ "${PROVISION_VERSION}" -eq 0 ]; then
  provision_1
  provision_2
  provision_3
  provision_4
  echo ${PROVISION_COUNT} > ${PROVISION_FILE}
elif [ ${PROVISION_VERSION} -ge ${PROVISION_COUNT} ]; then
  echo "Server already provisioned"
else
  for ((PROV_INC=`expr ${PROVISION_VERSION}+1`; PROV_INC<=${PROVISION_COUNT}; PROV_INC++)); do
    echo "Running provision ${PROV_INC}"
    eval "provision_${PROV_INC}"
    echo ${PROV_INC} > ${PROVISION_FILE}
  done
fi
exit 0
