#!/bin/bash

# Parameters
PROVISION_FILE=/etc/mongo-provisioned
PROVISION_COUNT=3 # Make sure to  update this when adding new updates!
PROVISION_FOLDER=
PROVISION_STEP=0

#
# usage() function to display script usage
#
function usage(){
  echo "Usage: $0 options

This script provisions a server to host the NHM data portal postgres
database. It will:
 - Install the mongo database ;

OPTIONS:
  -h   Show this message
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
# Parse arguments
#
while getopts "hp:r:x:" OPTION; do
  case $OPTION in
    h)
      usage
      exit 0
      ;;
    p)
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
# Install Mongo DB
#
function provision_1(){
  # Install mongodb
  echo "Installing Mongo DB"
  # We want latest version for the aggregate functions, so we need the 10 gen distro
  # Add key
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
  # Create list file
  echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
  # Update packages
  sudo apt-get update
  # And install
  sudo apt-get install mongodb-org
}

function provision_2(){
  # Install mongodb
  echo "Copy KE EMu dumps"
  # TODO:
}

function provision_3(){
  # Install mongodb
  echo "Run API to create datastore"
  # TODO:
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
  provision_2
  provision_3
  echo ${PROVISION_COUNT} > ${PROVISION_FILE}
else
  for ((i=`expr ${PROVISION_VERSION}+1`; i<=${PROVISION_COUNT}; i++)); do
    eval "provision_${i}"
    echo ${i} > ${PROVISION_FILE}
  done
fi
exit 0