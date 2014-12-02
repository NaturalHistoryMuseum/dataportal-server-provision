#!/usr/bin/env bash

# Parameters
PROVISION_FILE=/etc/postgres-provisioned
PROVISION_FOLDER=
DB_USER=ckan_default
DB_RO_USER=datastore_default
DB_WINDSHAFT_USER=datastore_windshaft
DB_PASS=
CKAN_DB_NAME=ckan_default
DATASTORE_DB_NAME=datastore_default
WINDSHAFT_IP=127.0.0.1
PROVISION_COUNT=2 # Keep this up to date
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
  -i   IP address of the windshaft server
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
    i)
      WINDSHAFT_IP=$OPTARG
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
  # Ensure we have passwords and admin email
  ensure_pass DB_PASS "ckan database"

  # Fix postgres encoding issue
  echo "Updating encoding"
  echo export LC_ALL=en_US.UTF-8 >> /etc/bash.bashrc
  echo export LANGUAGE=en_US.UTF-8 >> /etc/bash.bashrc
  echo export LANG=en_US.UTF-8 >> /etc/bash.bashrc
  export LC_ALL=en_US.UTF-8
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  locale-gen en_US.UTF-8
  dpkg-reconfigure locales
  locale

  # Install packages
  echo "Updating and installing packages"

  apt-get update
  apt-get install -y postgresql

  # Install config file & restart
  echo "Setting up..."
#  cat "$PROVISION_FOLDER/postgresql.conf" > /etc/postgresql/9.1/main/postgresql.conf
  cat "$PROVISION_FOLDER/pg_hba.conf" | sed -e "s~%DATASTORE_DB_NAME%~$DATASTORE_DB_NAME~"  -e "s~%DB_WINDSHAFT_USER%~$DB_WINDSHAFT_USER~" -e "s~%WINDSHAFT_IP%~$WINDSHAFT_IP~" > /etc/postgresql/9.1/main/pg_hba.conf
  service postgresql restart

  echo "Creating CKAN database"
  sudo -u postgres createuser -S -D -R $DB_USER
  sudo -u postgres psql -c "ALTER USER $DB_USER with password '$DB_PASS'"
  sudo -u postgres createdb -O $DB_USER $CKAN_DB_NAME -E UTF8

  # Datastore
  echo "Creating datastore database"
  sudo -u postgres createuser -S -D -R -l $DB_RO_USER
  sudo -u postgres psql -c "ALTER USER $DB_RO_USER with password '$DB_PASS'"
  sudo -u postgres createdb -O $DB_USER $DATASTORE_DB_NAME -E UTF8
  sudo -u postgres psql -c "CREATE EXTENSION citext"

  # Windshaft user
  echo "Creating windshaft user"
  sudo -u postgres createuser -S -D -R -l ${DB_WINDSHAFT_USER}
  sudo -u postgres psql -c "ALTER USER $DB_WINDSHAFT_USER with password '$DB_PASS'"
  sudo -u postgres psql -d ${DATASTORE_DB_NAME} -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $DB_WINDSHAFT_USER"
  sudo -u postgres psql -d ${DATASTORE_DB_NAME} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO $DB_WINDSHAFT_USER"

  # Set per-user work mem
  sudo -u postgres psql -c "ALTER ROLE $DB_USER SET work_mem='4MB'"
  sudo -u postgres psql -c "ALTER ROLE $DB_RO_USER SET work_mem='10MB'"
  sudo -u postgres psql -c "ALTER ROLE $DB_WINDSHAFT_USER SET work_mem='100MB'"
}

#
# Add post-gis support
#
function provision_2(){
  echo "Installing postgis"
  sudo apt-get install -y python-software-properties
  # Add the ubuntu gis stable repo
  # If postgis2.1 is required, it is available in the unstable: http://trac.osgeo.org/ubuntugis/wiki/UbuntuGISRepository
  sudo add-apt-repository -y ppa:ubuntugis/ppa
  apt-get update
  sudo apt-get install -y postgresql-9.1-postgis-2.0
  sudo -u postgres psql -d ${DATASTORE_DB_NAME} -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis.sql
  sudo -u postgres psql -d ${DATASTORE_DB_NAME} -c "ALTER TABLE geometry_columns OWNER TO $DB_USER"
  sudo -u postgres psql -d ${DATASTORE_DB_NAME} -c "ALTER TABLE spatial_ref_sys OWNER TO $DB_USER"
  sudo -u postgres psql -d ${DATASTORE_DB_NAME} -f /usr/share/postgresql/9.1/contrib/postgis-2.0/spatial_ref_sys.sql

  sudo -u postgres psql -d ${CKAN_DB_NAME} -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis.sql
  sudo -u postgres psql -d ${CKAN_DB_NAME} -c "ALTER TABLE geometry_columns OWNER TO $DB_USER"
  sudo -u postgres psql -d ${CKAN_DB_NAME} -c "ALTER TABLE spatial_ref_sys OWNER TO $DB_USER"
  sudo -u postgres psql -d ${CKAN_DB_NAME} -f /usr/share/postgresql/9.1/contrib/postgis-2.0/spatial_ref_sys.sql
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
  provision_2
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
