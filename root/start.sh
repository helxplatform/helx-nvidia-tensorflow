#!/bin/bash

set -eoux pipefail

export USER=${USER-"helx"}
export USER_UID=${USER_UID-"1000"}
export USER_GID=${USER_GID-"0"}
export DEFAULT_USER="helx"
# Use NB_PREFIX for base path of ttyd if it is set and BASE_PATH is not set.
# NB_PREFIX will be set if launched from HeLx.
export NB_PREFIX=${NB_PREFIX-"/"}
# if BASE_PATH is set then use that and override NB_PREFIX if set.
export BASE_PATH=${BASE_PATH-$NB_PREFIX}

declare -i CURRENT_UID=`id -u`
if [ $CURRENT_UID -ne 0 ]
then
  export HOME="/home/$USER"
else
  export HOME="/root"
fi

# Change to the root directory to mitigate problems if the current working
# directory is deleted.
cd /

# Add other init scripts in $HELX_SCRIPTS_DIR with ".sh" as their extension.
# To run in a certain order, name them appropriately.
HELX_SCRIPT_DIR=/helx
INIT_SCRIPTS_TO_RUN=$(ls -1 $HELX_SCRIPT_DIR/*.sh) || true
for INIT_SCRIPT in $INIT_SCRIPTS_TO_RUN
do
  echo "Running $INIT_SCRIPT"
  $INIT_SCRIPT
done

# Change CWD to /home/$USER so it is the starting point for shells.
cd $HOME

# Where user-specific non-essential (cached) data should be written (analogous to /var/cache).
# Should default to $HOME/.cache.
# https://wiki.archlinux.org/title/XDG_Base_Directory
export XDG_CACHE_HOME=$HOME/.cache

FINAL_COMMAND=${FINAL_COMMAND-"/start-last.sh"}
$FINAL_COMMAND
