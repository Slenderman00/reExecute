#!/bin/sh
# reExecute startup hook.
#
# Edit this file on the tablet:
#   /home/root/bin/reexecute-hook.sh
#
# This script is launched in the background by:
#   /home/root/bin/reexecute-user-authenticator-cli
#
# Keep it non-blocking. Start daemons/tunnels in the background.

LOG="/home/root/reexecute-hook.log"

echo "reExecute hook ran at $(date)" >>"$LOG"

# Put your persistent startup commands below.
#
# Example:
# echo "hello from reExecute" >> "$LOG"

exit 0
