# Special Container Setup
source /etc/mailinabox.conf $STORAGE_ROOT 

# Holds Management python Env and bootstrap.
-v /usr/local/lib/mailinabox:/usr/local/lib/mailinabox
# Holds api key
-v /var/lib/mailinabox/:/var/lib/mailinabox/
-v $STORAGE_ROOT:$STORAGE_ROOT
