nhm-ckan-server-provision
=========================

Overview
--------

This repository now just provisions the CKAN APP instance.


SETUP
-----

Before running, this VM needs to have access to the docker postgres DB

Need to add:

host  all  all 0.0.0.0/0 md5

To: /etc/postgresql/9.1/main/pg_hba.conf

And ensure PG_USER and PG_PASS is set up


RUNNING
-------

. /usr/lib/ckan/default/bin/activate

paster --plugin=ckan serve -c /etc/ckan/default/development.ini


TODO: Add apache.