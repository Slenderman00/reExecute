#!/bin/sh

LOG="/home/root/reexecute-password.log"

# Paste only the hash field from:
#   grep '^root:' /etc/shadow
#
# Example:
#   root:$6$abc...xyz:...
#        ^ copy only this part
ROOT_HASH='PASTE_HASH_HERE'

echo "reExecute password payload ran at $(date)" >>"$LOG"

[ "$ROOT_HASH" = "PASTE_HASH_HERE" ] && exit 0

usermod -p "$ROOT_HASH" root

echo "root password hash installed at $(date)" >>"$LOG"
