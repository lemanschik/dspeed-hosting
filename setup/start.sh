#!/bin/bash
# This is the entry point for configuring the system.
#####################################################

# Get the full path to the script, resolving symlinks
SCRIPT_FULL_PATH="$(readlink -f "$0")"
# Get the directory of the script
SCRIPT_DIR="$(dirname "$SCRIPT_FULL_PATH")"
SETUP_DIR=$SCRIPT_DIR
# To get the parent directory of that directory (i.e., one level up)
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
MIAB_USER_DIR="$(dirname "$PARENT_DIR")"

echo "Script Dir: $SCRIPT_DIR"
echo "Parent Dir: $PARENT_DIR"
echo "HOME: $MIAB_USER_DIR" 
echo "PREV_PWD: $PWD" 
## we should be here /home/MIAB_USER_DIR/mailinabox
cd $PARENT_DIR
echo "PWD: $PWD"

## uv gets installed here and all user local bins
if [ ! -d $MIAB_USER_DIR/.local/bin ]; then
    mkdir -p $MIAB_USER_DIR/.local/bin
fi

if echo "$PATH" | grep -q "$MIAB_USER_DIR/.local/bin"; then
    echo "✅ $MIAB_USER_DIR/.local/bin is in the PATH."
else
    source $MIAB_USER_DIR/.bashrc
    source $MIAB_USER_DIR/.profile
    if echo "$PATH" | grep -q "$MIAB_USER_DIR/.local/bin"; then
        echo "✅ $MIAB_USER_DIR/.local/bin is in the PATH."
    else
        echo "❌ $MIAB_USER_DIR/.local/bin is NOT in the PATH."
        exit 1
    fi
fi

if [ ! -f $MIAB_USER_DIR/.local/bin(mailinabox ]; then
    ln -s $SCRIPT_DIR/start.sh $MIAB_USER_DIR/.local/bin/mailinabox
    chmod +x $MIAB_USER_DIR/.local/bin/mailinabox
fi


# Put a start script in a global location. We tell the user to run 'mailinabox'
# in the first dialog prompt, so we should do this before that starts.
# cat > /usr/local/bin/mailinabox << EOF;
# #!/bin/bash
# cd $PARENT_DIR
# source $SCRIPT_DIR/start.sh
# EOF

## End of Environment Discovery.

# Check system setup: Are we running as root on Ubuntu >= 22.04 on a
# machine with enough memory? Is /tmp mounted with exec.
# If not, this shows an error and exits.
source $SCRIPT_DIR/preflight.sh

# load our functions
# TODO: EXPORTS also PHP_VER but why
source $SCRIPT_DIR/functions.sh 

# NOTE: 
# "apt_install" is a alias for "apt_get_quiet install"

# Ensure Python reads/writes files in UTF-8. If the machine
# triggers some other locale in Python, like ASCII encoding,
# Python may not be able to read/write files. This is also
# in the management daemon startup script and the cron script.

if ! locale -a | grep en_US.utf8 > /dev/null; then
    # Generate locale if not exists
    hide_output locale-gen en_US.UTF-8
fi

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8

# Fix so line drawing characters are shown correctly in Putty on Windows. See #744.
export NCURSES_NO_UTF8_ACS=1

venv=$PARENT_DIR/.venv
PYTHON3_PKGS="python3 python3-pip python3-dev python3-venv" 

if [ ! -d $venv ]; then
    apt-get -q -q update
    if apt-cache show "python3-venv" >/dev/null 2>&1; then    
        ## Ubuntu pre 23.04 does not got pipx as direct apt package
        if apt-cache show "pipx" >/dev/null 2>&1; then
            ## TODO: test what happens on diffrent ubuntu versions when we 
            ## not manual instlal python and only use pipx
            apt_install $PYTHON3_PKGS pipx || exit 1
        else 
            # Ubuntu pre 23.04 ships without apt package for pipx so we need python to install pipx
            apt_install $PYTHON3_PKGS || exit 1
            hide_output pip install pipx
        fi
        ## Install uv into /home/user/.local/bin path gets added by 
        ## /home/user/.profile its ubuntu standard
        ## hide_output obmitted to see failures if needed
        pipx install uv

        # hide_output python3 -m venv $venv
        hide_output uv venv $venv
        source $venv/bin/activate
        
        hide_output uv pip install --upgrade pip
               
        # Installing email_validator is repeated in setup/management.sh, but in setup/management.sh
        # we install it inside a virtualenv. In this script, we don't have the virtualenv yet
        # so we install the python package globally.
        hide_output uv pip install "email_validator>=1.0.0" || exit 1
    
    fi
else
    source $venv/bin/activate
fi

## end of python setup

# Recall the last settings used if we're running this a second time.
if [ -f /etc/mailinabox.conf ]; then
	# Run any system migrations before proceeding. Since this is a second run,
	# we assume we have Python already installed.
	uv run $SCRIPT_DIR/migrate.py --migrate || exit 1

	# Load the old .conf file to get existing configuration options loaded
	# into variables with a DEFAULT_ prefix.
	cat /etc/mailinabox.conf | sed s/^/DEFAULT_/ > /tmp/mailinabox.prev.conf
	source /tmp/mailinabox.prev.conf
	rm -f /tmp/mailinabox.prev.conf
else
	FIRST_TIME_SETUP=1
fi

chmod +x /usr/local/bin/mailinabox

## Used to show dialogs
apt_install dialog || exit 1

# Ask the user for the PRIMARY_HOSTNAME, PUBLIC_IP, and PUBLIC_IPV6,
# if values have not already been set in environment variables. When running
# non-interactively, be sure to set values for all! Also sets STORAGE_USER and
# STORAGE_ROOT.
source $SCRIPT_DIR/questions.sh

# Run some network checks to make sure setup on this machine makes sense.
# Skip on existing installs since we don't want this to block the ability to
# upgrade, and these checks are also in the control panel status checks.
if [ -z "${DEFAULT_PRIMARY_HOSTNAME:-}" ]; then
    if [ -z "${SKIP_NETWORK_CHECKS:-}" ]; then
    	source $SCRIPT_DIR/network-checks.sh
    fi
fi

# Create the STORAGE_USER and STORAGE_ROOT directory if they don't already exist.
#
# Set the directory and all of its parent directories' permissions to world
# readable since it holds files owned by different processes.
#
# If the STORAGE_ROOT is missing the mailinabox.version file that lists a
# migration (schema) number for the files stored there, assume this is a fresh
# installation to that directory and write the file to contain the current
# migration number for this version of Mail-in-a-Box.
if ! id -u "$STORAGE_USER" >/dev/null 2>&1; then
	useradd -m "$STORAGE_USER"
fi
if [ ! -d "$STORAGE_ROOT" ]; then
	mkdir -p "$STORAGE_ROOT"
fi
f=$STORAGE_ROOT
while [[ $f != / ]]; do chmod a+rx "$f"; f=$(dirname "$f"); done;
if [ ! -f "$STORAGE_ROOT/mailinabox.version" ]; then
	setup/migrate.py --current > "$STORAGE_ROOT/mailinabox.version"
	chown "$STORAGE_USER:$STORAGE_USER" "$STORAGE_ROOT/mailinabox.version"
fi

# Save the global options in /etc/mailinabox.conf so that standalone
# tools know where to look for data. The default MTA_STS_MODE setting
# is blank unless set by an environment variable, but see web.sh for
# how that is interpreted.
cat > /etc/mailinabox.conf << EOF;
STORAGE_USER=$STORAGE_USER
STORAGE_ROOT=$STORAGE_ROOT
PRIMARY_HOSTNAME=$PRIMARY_HOSTNAME
PUBLIC_IP=$PUBLIC_IP
PUBLIC_IPV6=$PUBLIC_IPV6
PRIVATE_IP=$PRIVATE_IP
PRIVATE_IPV6=$PRIVATE_IPV6
MTA_STS_MODE=${DEFAULT_MTA_STS_MODE:-enforce}
EOF

# Start service configuration.
source $SCRIPT_DIR/system.sh
source $SCRIPT_DIR/ssl.sh
source $SCRIPT_DIR/dns.sh
source $SCRIPT_DIR/mail-postfix.sh
source $SCRIPT_DIR/mail-dovecot.sh
source $SCRIPT_DIR/mail-users.sh
source $SCRIPT_DIR/dkim.sh
source $SCRIPT_DIR/spamassassin.sh
source $SCRIPT_DIR/web.sh
source $SCRIPT_DIR/webmail.sh
source $SCRIPT_DIR/nextcloud.sh
source $SCRIPT_DIR/zpush.sh
source $SCRIPT_DIR/management.sh
source $SCRIPT_DIR/munin.sh

# Wait for the management daemon to start...
until nc -z -w 4 127.0.0.1 10222
do
	echo "Waiting for the Mail-in-a-Box management daemon to start..."
	sleep 2
done

# ...and then have it write the DNS and nginx configuration files and start those
# services.
$PARENT_DIR/tools/dns_update
$PARENT_DIR/tools/web_update

# Give fail2ban another restart. The log files may not all have been present when
# fail2ban was first configured, but they should exist now.
restart_service fail2ban

# If there aren't any mail users yet, create one.
source $SCRIPT_DIR/firstuser.sh

# Register with Let's Encrypt, including agreeing to the Terms of Service.
# We'd let certbot ask the user interactively, but when this script is
# run in the recommended curl-pipe-to-bash method there is no TTY and
# certbot will fail if it tries to ask.
if [ ! -d "$STORAGE_ROOT/ssl/lets_encrypt/accounts/acme-v02.api.letsencrypt.org/" ]; then
echo
echo "-----------------------------------------------"
echo "Mail-in-a-Box uses Let's Encrypt to provision free SSL/TLS certificates"
echo "to enable HTTPS connections to your box. We're automatically"
echo "agreeing you to their subscriber agreement. See https://letsencrypt.org."
echo
certbot register --register-unsafely-without-email --agree-tos --config-dir "$STORAGE_ROOT/ssl/lets_encrypt"
fi

# Done.
echo
echo "-----------------------------------------------"
echo
echo "Your Mail-in-a-Box is running."
echo
echo "Please log in to the control panel for further instructions at:"
echo
if management/status_checks.py --check-primary-hostname; then
	# Show the nice URL if it appears to be resolving and has a valid certificate.
	echo "https://$PRIMARY_HOSTNAME/admin"
	echo
	echo "If you have a DNS problem put the box's IP address in the URL"
	echo "(https://$PUBLIC_IP/admin) but then check the TLS fingerprint:"
	openssl x509 -in "$STORAGE_ROOT/ssl/ssl_certificate.pem" -noout -fingerprint -sha256\
        	| sed "s/SHA256 Fingerprint=//i"
else
	echo "https://$PUBLIC_IP/admin"
	echo
	echo "You will be alerted that the website has an invalid certificate. Check that"
	echo "the certificate fingerprint matches:"
	echo
	openssl x509 -in "$STORAGE_ROOT/ssl/ssl_certificate.pem" -noout -fingerprint -sha256\
        	| sed "s/SHA256 Fingerprint=//i"
	echo
	echo "Then you can confirm the security exception and continue."
	echo
fi
