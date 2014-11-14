#!/usr/bin/env bash
# Pre-generate the main DwC archives, and inform data@nhm.ac.uk

CKP_ROOT=/usr/lib/ckan/ckanpackager
CKP_CMD=$CKP_ROOT/bin/ckanpackager

. $CKP_ROOT/bin/activate
$CKP_CMD cc
$CKP_CMD queue package_dwc_archive offset:0 limit:10
