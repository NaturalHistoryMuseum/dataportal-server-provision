#!/usr/bin/env bash

# Parameters
PROVISION_FILE=/etc/solr-provisioned
PROVISION_FOLDER=
PROVISION_COUNT=1 # Keep this up to date otherwise updates might get applied.
PROVISION_STEP=0
UPDATE=false

#
# usage() function to display script usage
#
function usage(){
  echo "Usage: $0 options

This script provisions a server to host the NHM data portal solr
server. It will:
- Install the solr server (tomcat) ;
- Setup the solr schema file

OPTIONS:
  -h   Show this message
  -r   Path to folder container provisioning resources.
       This defaults to the path of the current script,
       however when provision via Vagrant this might not
       be what you expect, so it is safer to set this.
  -u   Update: refresh the solr schema and restart the
       solr server
  -x   Set the provision step to run. Note that running this WILL NOT
       UPDATE THE CURRENT PROVISION VERSION. Edit ${PROVISION_FILE}
       manually for this.
"
}

#
# Parse arguments
#
while getopts "hr:ux:" OPTION; do
  case ${OPTION} in
    h)
      usage
      exit 0
      ;;
    r)
      PROVISION_FOLDER=${OPTARG}
      ;;
    u)
      UPDATE=true
      ;;
    x)
      PROVISION_STEP=${OPTARG}
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done
# Set the default provision folder
if [ "${PROVISION_FOLDER}" = "" ]; then
  PROVISION_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

#
# Update the solr schema
#
function update_solr_schema(){
  # Test we have required files in the provision folder
  if [ ! -f "${PROVISION_FOLDER}/schema.xml" ]; then
    echo "Missing file ${PROVISION_FOLDER}/schema.xml ; aborting." 1>&2
    exit 1
  fi

  # SOLR
  echo "Setting up SOLR"
  mv /etc/solr/conf/schema.xml /etc/solr/conf/schema.xml.bak
  cp ${PROVISION_FOLDER}/schema.xml /etc/solr/conf/schema.xml
  service tomcat6 restart
}

#
# Initial provision script
#
function provision_1(){
  # Test we have required files in the provision folder
  if [ ! -f "${PROVISION_FOLDER}/schema.xml" ]; then
    echo "Missing file ${PROVISION_FOLDER}/schema.xml ; aborting." 1>&2
    exit 1
  fi

  # Install packages
  echo "Updating and installing packages"
  apt-get update
  apt-get install -y solr-tomcat

  update_solr_schema
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
elif [ ${PROVISION_VERSION} -ge ${PROVISION_COUNT} ]; then
  echo "Server already provisioned"
elif [ ${PROVISION_VERSION} -eq 0 ]; then
  provision_1
  echo ${PROVISION_COUNT} > ${PROVISION_FILE}
else
  for ((i=`expr ${PROVISION_VERSION}+1`; i<=${PROVISION_COUNT}; i++)); do
    eval "provision_${i}"
    echo ${i} > ${PROVISION_FILE}
  done
fi
exit 0