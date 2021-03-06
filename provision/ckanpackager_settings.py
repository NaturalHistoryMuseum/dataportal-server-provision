# Debug mode
DEBUG = False

# host and port. 127.0.0.1 will only serve locally - set to 0.0.0.0 (or iface IP) to have available externally.
HOST = '0.0.0.0'
PORT = 8765

# Secret key. This ensures only approved applications can use this. YOU MUST CHANGE THIS VALUE TO YOUR OWN SECRET!
SECRET = ''

# Number of workers. Each worker processes one job at a time.
WORKERS = 1

# Number of requests each worker should process before being restarted.
REQUESTS_PER_WORKER = 1000

# Directory where the zip files are stored
STORE_DIRECTORY = "/var/www/ckan-resources/resources"

# Temp Directory used when creating the files
TEMP_DIRECTORY = "/tmp"

# Amount of time (in seconds) for which a specific request (matching same parameters) is cached. This will always be at
# least 1s.
CACHE_TIME = 60*60*24*7

# Page Size. Number of rows to fetch in a single CKAN request. Note that CKAN will timeout requests at 60s, so make sure
# to stay comfortably below that line.
PAGE_SIZE = 5000

# Shell command used to zip the file. {input} gets replaced by the input file name, and {output} by the output file
# name. You do not need to put quotes around those.
ZIP_COMMAND = "/usr/bin/zip -j {output} {input}"

# Message sent back when returning success
SUCCESS_MESSAGE = "The resource will be emailed to you shortly. This make take a little longer if our servers are busy, so please be patient!"

# Email subject line. Available placeholders:
# {resource_id}: The resource id,
# {zip_file_name}: The file name,
# {ckan_host}: The hostname of the CKAN server the query was made to,
EMAIL_SUBJECT = "Resource from {ckan_host}"

# Email FROM line. See Email subject for placeholders.
EMAIL_FROM = "(nobody)"

# Email body. See Email subject for placeholders.
EMAIL_BODY = """Hello,

The link to the resource you requested on {ckan_host} is available at:
http://ckan-data.nhm.ac.uk/resources/{zip_file_name}

Best Wishes,
The Data Portal Bot
"""

# SMTP host:port
SMTP_HOST = 'mailserver.nhm.ac.uk'

# SMTP username (Optional, if required)
#SMTP_LOGIN = ''

# SMTP password (Optional, if required)
#SMTP_PASSWORD = ''

DWC_EXTENSION_PATHS = ['/usr/lib/ckan/ckanpackager/src/ckanpackager/deployment/gbif_dwca_extensions/core/dwc_occurrence.xml']
DWC_DYNAMIC_TERM = 'dynamicProperties'
DWC_ID_FIELD = '_id'
