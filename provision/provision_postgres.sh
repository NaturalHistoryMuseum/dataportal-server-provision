#!/usr/bin/env bash

# Parameters
PROVISION_FILE=/etc/postgres-provisioned
PROVISION_FOLDER=
DB_USER=ckan_default
DB_RO_USER=datastore_default
DB_PASS=
CKAN_DB_NAME=ckan_default
DATASTORE_DB_NAME=datastore_default
PROVISION_COUNT=1 # Keep this up to date
PROVISION_STEP=0

#
# usage() function to display script usage
#
function usage(){
  echo "Usage: $0 options

This script provisions a server to host the NHM data portal postgres
database. It will:
 - Install the postgres server ;
 - Create a system user ($DB_USER)  ;
 - Create a read only user ($DB_RO_USER) ;
 - Create the Ckan database ($CKAN_DB_NAME) ;
 - Create the datastore database ($DATASTORE_DB_NAME) ;
 - Upload the datastore.sql file in the datastore database
   (this file must exist in the provisioning folder, see 
   option -r)

OPTIONS:
  -h   Show this message
  -p   Postgres password.
       If password is not defined  the script will prompt
       the user for the password.
  -r   Path to folder containing provisioning resources.
       This defaults to the path of the current script, 
       however when provisioning via Vagrant this might
       not be what you expect, so it is safer to set
       this.
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
    echo ${!VARNAME} | grep -q '^[-_+*0-9a-zA-Z]*$'
    if [ $? -ne 0 ]; then
      echo "Only -_+*0-9a-zA-Z allowed in password."
      eval "${VARNAME}="
    fi
  done
}

#
# Parse arguments
#
while getopts "hp:r:x:" OPTION; do
  case $OPTION in
    h)
      usage
      exit 0
      ;;
    p)
      DB_PASS=$OPTARG
      ;;
    r)
      PROVISION_FOLDER=$OPTARG
      ;;
    x)
      PROVISION_STEP=$OPTARG
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done
# Set the default provision folder
if [ "$PROVISION_FOLDER" = "" ]; then
  PROVISION_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

#
# This is the main provisioning function
# that is run on new server installations
#
function provision_1(){
  # Test we have required files in the provision folder
  if [ ! -f "$PROVISION_FOLDER/datastore.sql" ]; then
    echo "Missing file $PROVISION_FOLDER/development.ini ; aborting." 1>&2
    exit 1
  fi
  # Ensure we have passwords and admin email
  ensure_pass DB_PASS "ckan database"

  # Fix postgres encoding issue
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  locale-gen en_US.UTF-8
  dpkg-reconfigure locales

  # Install packages
  echo "Updating and installing packages"
  apt-get update
  apt-get install -y postgresql

  echo "Creating CKAN database"
  sudo -u postgres createuser -S -D -R $DB_USER
  sudo -u postgres psql -c "ALTER USER $DB_USER with password '$DB_PASS'"
  sudo -u postgres createdb -O $DB_USER $CKAN_DB_NAME -E UTF8 --locale=en_US.UTF-8 -T template0

  # Datastore
  echo "Creating datastore database"
  sudo -u postgres createuser -S -D -R -l $DB_RO_USER 
  sudo -u postgres psql -c "ALTER USER $DB_RO_USER with password '$DB_PASS'"
  sudo -u postgres createdb -O $DB_USER $DATASTORE_DB_NAME -E UTF8 --locale=en_US.UTF-8 -T template0

  echo "Importing datastore dump"
  sudo -u postgres psql $DATASTORE_DB_NAME < "$PROVISION_FOLDER/datastore.sql"

  echo "All done."
}

#
# Work out current version and apply the appropriate provisioning script.
#
if [ ! -f ${PROVISION_FILE} ]; then
  PROVISION_VERSION=0
else
  PROVISION_VERSION=`cat ${PROVISION_FILE}`
fi
if [ ${PROVISION_STEP} -ne 0 ]; then
  eval "provision_${PROVISION_STEP}"
elif [ ${PROVISION_VERSION} -eq 0 ]; then
  provision_1
  echo ${PROVISION_COUNT} > ${PROVISION_FILE}
elif [ ${PROVISION_VERSION} -ge ${PROVISION_COUNT} ]; then
  echo "Server already provisioned"
else
  for ((i=`expr ${PROVISION_VERSION}+1`; i<=${PROVISION_COUNT}; i++)); do
    eval "provision_${i}"
    echo ${i} > ${PROVISION_FILE}
  done
fi
exit 0
