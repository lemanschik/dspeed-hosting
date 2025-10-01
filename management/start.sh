#!/bin/bash
## this script should get used only by the systemctl deamon.

# Set character encoding flags to ensure that any non-ASCII don't cause problems.
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8

mkdir -p /var/lib/mailinabox
tr -cd '[:xdigit:]' < /dev/urandom | head -c 32 > /var/lib/mailinabox/api.key
chmod 640 /var/lib/mailinabox/api.key

echo "Starting Gunicorn server via uv run..."

# Set PYTHONPATH ONLY for this command execution to ensure Gunicorn finds modules in 'management'
PYTHONPATH=$PWD/management \
  uv run gunicorn -b localhost:10222 -w 1 --timeout 630 wsgi:app
