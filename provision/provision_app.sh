#!/usr/bin/env bash

DEV_MODE=1
SYNCED_FOLDER=/vagrant
PROVISION_FILE=/etc/app-provisioned
PROVISION_COUNT=6 # Make sure to update this when adding new updates!
PROVISION_STEP=0

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
# Read options
#
while getopts "hdp:e:j:x:r:g:" OPTION; do
  case $OPTION in
    h)
      usage
      exit 0
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

# Settings configuration
source "$PROVISION_FOLDER/settings.cfg"

#
# Initial provision, step 1: install required packages
#
function provision_1(){
  # Install packages
  echo "Updating and installing packages"
  apt-get update
  # We need the postgres client to connect to docker
  apt-get install -y python-dev python-pip python-virtualenv python-pastescript build-essential libpq-dev libxslt1-dev libxml2-dev git-core postgresql-client-common postgresql-client-8.4 libgeos-dev libldap2-dev libsasl2-dev libssl-dev
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
  export CKAN_DB_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME"
  export DATASTORE_DB_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DB_DATASTORE_NAME"
  export DATASTORE_DB_RO_URL="postgresql://$DB_RO_USER:$DB_PASS@$DB_HOST/$DB_DATASTORE_NAME"

  #  Replace variable placeholders in development.ini - need to be in environment
  export SOLR_URL CKANPACKAGER_URL CKANPACKAGER_SECRET DATAPUSHER_URL CKANPACKAGER_URL CKANPACKAGER_SECRET GBIF_USERNAME GBIF_PASSWORD DOI_PASSWORD WINDSHAFT_HOST WINDSHAFT_PORT LDAP_URI LDAP_AUTH_DN LDAP_AUTH_PASS LDAP_BASE_DN GOOGLE_ANALYTICS
  envsubst < "${PROVISION_FOLDER}/development.ini" > /etc/ckan/default/development.ini

  # Create virtual env
  echo "Creating virtual environment"
  mkdir -p /usr/lib/ckan/default
  virtualenv /usr/lib/ckan/default

  echo "Creating log directory"
  mkdir -p /var/log/nhm/
  sudo chmod -R 0777 /var/log/nhm/

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
    chmod -R 0777 /var/lib/ckan
  fi

  # WHO.INI
  echo "Creating who.ini link"
  ln -fs /usr/lib/ckan/default/src/ckan/who.ini /etc/ckan/default/who.ini
}

#
# Initial provision, step 4: Install CKAN NHM extension and requirements.
#
function provision_4(){

  cd /usr/lib/ckan/default
  . /usr/lib/ckan/default/bin/activate

  pip install -e 'git+https://github.com/NaturalHistoryMuseum/ckanext-nhm.git#egg=ckanext_nhm'
  if [ $? -ne 0 ]; then
    echo "Failed installing ckanext-nhm ; aborting" 1>&2
    exit 1
  fi

  echo "Install NHM CKAN requirements"
  pip_install_req /usr/lib/ckan/default/src/ckanext-nhm/requirements.txt
  # We need to manually install shapely <1.3 - see https://github.com/ckan/ckanext-spatial/issues/94
  pip install 'shapely<1.3'
  pip_install_req /usr/lib/ckan/default/src/ckanext-spatial/pip-requirements.txt
  pip_install_req /usr/lib/ckan/default/src/ckanext-map/requirements.txt
  pip_install_req /usr/lib/ckan/default/src/ckanext-doi/requirements.txt
  pip_install_req /usr/lib/ckan/default/src/ckanext-ldap/requirements.txt

}

#
# Initial provision, step 6: Set up database
#
function provision_5(){
  cd /usr/lib/ckan/default
  . /usr/lib/ckan/default/bin/activate
  echo "Init databases"
  paster --plugin=ckan db init -c /etc/ckan/default/development.ini
  paster --plugin=ckan user add admin email="$CKAN_ADMIN_EMAIL" password="$CKAN_ADMIN_PASS" -c /etc/ckan/default/development.ini
  paster --plugin=ckan sysadmin add admin -c /etc/ckan/default/development.ini

  # Set permissions - piped to psql
  paster --plugin=ckan datastore set-permissions -c /etc/ckan/default/development.ini | PGPASSWORD=$DB_ADMIN_PASS psql -h $DB_HOST -U $DB_ADMIN_USER

  # Init NHM database table - uses resource id foreign key so needs to come after the core ckan initdb
  cd /usr/lib/ckan/default/src/ckanext-nhm
  paster --plugin=ckanext-nhm initdb -c  /etc/ckan/default/development.ini

  # Create dataset type vocabularies
  paster --plugin=ckanext-nhm dataset-category create-vocabulary -c /etc/ckan/default/development.ini

  # Add organisation
  paster --plugin=ckanext-ldap ldap setup-org -c /etc/ckan/default/development.ini

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
#  provision_1
#  provision_2
  provision_3
  provision_4
#  provision_5
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
