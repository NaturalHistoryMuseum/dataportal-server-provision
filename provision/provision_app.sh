#!/usr/bin/env bash

# Parameters
DEV_MODE=0
SYNCED_FOLDER=/vagrant
PROVISION_FILE=/etc/app-provisioned
PROVISION_COUNT=7 # Make sure to  update this when adding new updates!
PROVISION_FOLDER=
PROVISION_STEP=0

CKAN_ADMIN_EMAIL=
CKAN_ADMIN_PASS=

DB_USER=ckan_default
DB_RO_USER=datastore_default
DB_HOST=localhost
DB_PASS=

CKAN_DB_NAME=ckan_default
DATASTORE_DB_NAME=datastore_default


#
# usage() function to display script usage
#
function usage(){
  echo "Usage: $0 options

This script provisions a server to host the NHM data portal
application server. It will:
- Install CKAN from the NHM git clone, and it's dependencies ;
- Install the NHM Ckan extention, and it's dependencies ;


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
  -e   Ckan admin email. If not defined, user will be prompted for it.
  -j   Ckan admin password. If not defined, user will be prompted for it ;
  -x   Set the provision step to run. Note that running this WILL NOT
       UPDATE THE CURRENT PROVISION VERSION. Edit ${PROVISION_FILE}
       manually for this.
"
}


#
# pip_install_req function ; takes one parameter as a
# path to a requirements.txt file.
#
function pip_install_req(){
  RETURN_STATUS=0
  for i in {1..3}; do
    pip --timeout=30 --exists-action=i install -r $1
    RETURN_STATUS=$?
    [ ${RETURN_STATUS} -eq 0 ] && break
  done
  if [ ${RETURN_STATUS} -ne 0 ]; then
    echo "Failed installing requirements ; aborting" 1>&2
    exit 1
  fi
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
while getopts "hdp:e:j:x:r:g:" OPTION; do
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
    e)
      CKAN_ADMIN_EMAIL=$OPTARG
      ;;
    j)
      CKAN_ADMIN_PASS=$OPTARG
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
# Initial provision, step 1: install required packages
#
function provision_1(){

  # Install packages
  echo "Updating and installing packages"
  apt-get update
  apt-get install -y python-dev python-pip python-virtualenv python-pastescript build-essential libpq-dev libxslt1-dev libxml2-dev git-core mongodb libicu-dev libyaml-perl
}

#
# Initial provision, step 2: Create development links, ckan ini file and python virtual environement
#
function provision_2(){
  if [ ! -f "${PROVISION_FOLDER}/development.ini" ]; then
    echo "Missing file ${PROVISION_FOLDER}/development.ini ; aborting." 1>&2
    exit 1
  fi

  # Symlinks (Development only)
  if [ ${DEV_MODE} -eq 1 ]; then
    echo "Setting up symlinks"
    mkdir -p "${SYNCED_FOLDER}/lib"
    [ -d /usr/lib/ckan ] && mv /usr/lib/ckan /usr/lib/ckan.bak
    ln -fs "${SYNCED_FOLDER}/lib" /usr/lib/ckan
    mkdir -p "${SYNCED_FOLDER}/etc"
    [ -d /etc/ckan ] && mv /etc/ckan /etc/ckan.bak
    ln -fs "${SYNCED_FOLDER}/etc" /etc/ckan
  fi

  # Config
  echo "Creating config"
  mkdir -p /etc/ckan/default
  CKAN_DB_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST/$CKAN_DB_NAME"
  DATASTORE_DB_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DATASTORE_DB_NAME"
  DATASTORE_DB_RO_URL="postgresql://$DB_RO_USER:$DB_PASS@$DB_HOST/$DATASTORE_DB_NAME"
  cat "${PROVISION_FOLDER}/development.ini" | sed -e "s~%CKAN_DB_URL%~$CKAN_DB_URL~" -e "s~%DATASTORE_DB_URL%~$DATASTORE_DB_URL~" -e "s~%DATASTORE_DB_RO_URL%~$DATASTORE_DB_RO_URL~" > /etc/ckan/default/development.ini

  # Create virtual env
  echo "Creating virtual environment"
  mkdir -p /usr/lib/ckan/default
  virtualenv /usr/lib/ckan/default

  echo "Creating log directory"
  sudo chmod -R 0777 /var/log/
  mkdir -p /var/log/nhm/

}

#
# Initial provision, step 3: Install CKAN, ckan requirements, and set up filestore and who.ini
#
function provision_3(){
  cd /usr/lib/ckan/default
  . /usr/lib/ckan/default/bin/activate

    # Install CKAN
  echo "Installing CKAN"
  pip install -e 'git+https://github.com/NaturalHistoryMuseum/ckan.git#egg=ckan'
  if [ $? -ne 0 ]; then
    echo "Failed installing ckan.git; aborting." 1>&2
    exit 1
  fi
  cd /usr/lib/ckan/default/src/ckan

  # Install ckan requirements
  echo "Installing CKAN requirements"
  pip_install_req /usr/lib/ckan/default/src/ckan/requirements.txt

  # Filestore (Development only)
  if [ ${DEV_MODE} -eq 1 ]; then
    echo "Enabling filestore with local storage"
    mkdir -p /var/lib/ckan/default
    # CKAN install instructions is for apache only; will not work with paste
    chmod 0777 /var/lib/ckan/default
  fi

  # WHO.INI
  echo "Creating who.ini link"
  ln -fs /usr/lib/ckan/default/src/ckan/who.ini /etc/ckan/default/who.ini
}

#
# Initial provision, step 4: Install CKAN NHM extension and requirements.
#
function provision_4(){
  if [ ! -f "${PROVISION_FOLDER}/client.cfg" ]; then
    echo "Missing file ${PROVISION_FOLDER}/client.cfg ; aborting." 1>&2
    exit 1
  fi

  cd /usr/lib/ckan/default
  . /usr/lib/ckan/default/bin/activate

  pip install -e 'git+https://github.com/NaturalHistoryMuseum/ckanext-nhm.git#egg=ckanext_nhm'
  if [ $? -ne 0 ]; then
    echo "Failed installing ckanext-nhm ; aborting" 1>&2
    exit 1
  fi

  echo "Install CKAN NHM requirements"
  pip_install_req /usr/lib/ckan/default/src/ckanext-nhm/requirements.txt
  pip_install_req /usr/lib/ckan/default/src/ckanext-map/requirements.txt

}

#
# Initial provision, step 5: Set up database
#
function provision_5(){
  cd /usr/lib/ckan/default
  . /usr/lib/ckan/default/bin/activate
  echo "Init databases"
  paster --plugin=ckan db init -c /etc/ckan/default/development.ini
  paster --plugin=ckan user add admin email="$CKAN_ADMIN_EMAIL" password="$CKAN_ADMIN_PASS" -c /etc/ckan/default/development.ini
  paster --plugin=ckan sysadmin add admin -c /etc/ckan/default/development.ini
  paster --plugin=ckan datastore set-permissions postgres -c /etc/ckan/default/development.ini

  # Init NHM database table - har resource id foreign key so needs to come after the core ckan initdb
  cd /usr/lib/ckan/default/src/ckanext-nhm
  paster --plugin=ckanext-nhm initdb -c  /vagrant/etc/default/development.ini

  # Init GA Report tables
  cd /usr/lib/ckan/default/src/ckanext-ga-report
  paster --plugin=ckanext-ga-report initdb -c  /vagrant/etc/default/development.ini
}

#
# Initial provision, step 6: Set up datapusher
#
function provision_6(){

    echo "Installing datapusher"

    apt-get install -y apache2 libapache2-mod-wsgi

    # create and activate a virtualenv for datapusher
    sudo virtualenv /usr/lib/ckan/datapusher
    . /usr/lib/ckan/datapusher/bin/activate

    # create a source directory
    mkdir -p /usr/lib/ckan/datapusher/src

    pip install -e 'git+https://github.com/ckan/datapusher.git#egg=datapusher'

    if [ $? -ne 0 ]; then
        echo "Failed installing datapusher ; aborting" 1>&2
        exit 1
    fi

    #install the DataPusher and its requirements
    pip_install_req /usr/lib/ckan/datapusher/src/datapusher/requirements.txt

    echo "Copying datapusher config files"

    #copy the standard Apache config file
    sudo cp /usr/lib/ckan/datapusher/src/datapusher/deployment/datapusher /etc/apache2/sites-available/

    #copy the standard DataPusher wsgi file
    sudo cp /usr/lib/ckan/datapusher/src/datapusher/deployment/datapusher.wsgi /etc/ckan/

    #copy the standard DataPusher settings.
    sudo cp /usr/lib/ckan/datapusher/src/datapusher/deployment/datapusher_settings.py /etc/ckan/

    echo "Setting up Apache"

    #open up port 8800 on Apache where the DataPusher accepts connections.
    sudo sh -c 'echo "NameVirtualHost *:8800" >> /etc/apache2/ports.conf'
    sudo sh -c 'echo "Listen 8800" >> /etc/apache2/ports.conf'

    #enable DataPusher Apache site
    sudo a2ensite datapusher
    sudo service apache2 restart
}

#
# Initial provision, step 7: Set up logging
#
function provision_7(){
  echo "Setting up logs"
  mkdir -p /var/log/nhm
  sudo chmod -R 0777 /var/log/nhm
}

#
# Work out current version and apply the appropriate provisioning script.
# Note that this script has 5 initial steps, rather than 1.
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
  provision_5
  provision_6
  provision_7
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
