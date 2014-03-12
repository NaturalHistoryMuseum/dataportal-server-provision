nhm-ckan-server-provision
=========================

Overview
--------

This repository contains a number of scripts for provisioning servers for the Natural History Museum
CKAN data portal. There are scripts for provisioning:

- The postgres database server ;
- The solr server ;
- The ckan application server (including the NHM specific extentions).

Notes
-----
- These scripts are meant to be run on an Ubuntu 12.04 LTS server ;
- The Windshaft server is provisioned using a different repository ;
- The repository also includes a Vagrant file that will provision a single VM running all those services ;
- Each of the script may contain initial provision steps (for new setups) and updates (to be applied to existing servers). The current version of each server is stored in a file of the form /etc/[type]-provisioned. Running the script will detect the current version and apply required patches or set up a new server as required ;
- To provision the database server you will need a dump of the KE dataset, named 'datastore.sql' and stored in the provisioning folder.
- You can run the scripts with '-h' to see available options (also check the Vagrantfile for example use)

