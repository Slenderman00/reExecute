#!/usr/bin/env bash
set -euo pipefail

RM_HOST="${RM_HOST:-10.11.99.1}"
RM_USER="${RM_USER:-root}"

MDM_CFG="/home/root/.local/share/remarkable/mdm/mdm-agent.toml"
MDM_CFG_BACKUP="/home/root/.local/share/remarkable/mdm/mdm-agent.toml.reexecute.bak"

REMOTE_BIN_DIR="/home/root/bin"
WRAPPER_PATH="/home/root/bin/reexecute-user-authenticator-cli"
HOOK_PATH="/home/root/bin/reexecute-hook.sh"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

require_cmd ssh
require_cmd sshpass

echo "reExecute installer"
echo
echo "Target: ${RM_USER}@${RM_HOST}"
echo "Connect your reMarkable over USB before continuing."
echo

read -rsp "reMarkable root SSH password: " RM_PASS
echo

if [ -z "$RM_PASS" ]; then
  echo "error: password cannot be empty" >&2
  exit 1
fi

SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10
)

remote_sh() {
  sshpass -p "$RM_PASS" ssh "${SSH_OPTS[@]}" "${RM_USER}@${RM_HOST}" "$@"
}

echo
echo "Checking SSH connection..."
remote_sh 'echo "connected to $(hostname)"'

echo
echo "Installing persistent files..."

sshpass -p "$RM_PASS" ssh "${SSH_OPTS[@]}" "${RM_USER}@${RM_HOST}" "sh -s" <<'REMOTE'
set -eu

MDM_CFG="/home/root/.local/share/remarkable/mdm/mdm-agent.toml"
MDM_CFG_BACKUP="/home/root/.local/share/remarkable/mdm/mdm-agent.toml.reexecute.bak"

REMOTE_BIN_DIR="/home/root/bin"
WRAPPER_PATH="/home/root/bin/reexecute-user-authenticator-cli"
HOOK_PATH="/home/root/bin/reexecute-hook.sh"

REAL_USER_AUTH="/usr/bin/user-authenticator-cli"

if [ ! -f "$MDM_CFG" ]; then
  echo "error: MDM config not found: $MDM_CFG" >&2
  exit 1
fi

if [ ! -x "$REAL_USER_AUTH" ]; then
  echo "error: real user-authenticator-cli not found: $REAL_USER_AUTH" >&2
  exit 1
fi

mkdir -p "$REMOTE_BIN_DIR"

# Keep the first backup. Never overwrite a known-good original.
if [ ! -f "$MDM_CFG_BACKUP" ]; then
  cp "$MDM_CFG" "$MDM_CFG_BACKUP"
fi

cat > "$WRAPPER_PATH" <<'EOF_WRAPPER'
#!/bin/sh
# reExecute MDM wrapper.
#
# MDM calls this through:
# /home/root/.local/share/remarkable/mdm/mdm-agent.toml
#
# This wrapper must never block or break MDM:
# 1. log the call
# 2. run the user's hook in the background
# 3. immediately forward to the real user-authenticator-cli

LOG="/home/root/reexecute-wrapper.log"
HOOK="/home/root/bin/reexecute-hook.sh"
REAL="/usr/bin/user-authenticator-cli"

{
  echo "reExecute wrapper called at $(date) args: $*"
} >> "$LOG" 2>/dev/null || true

if [ -x "$HOOK" ]; then
  (
    "$HOOK"
  ) >/dev/null 2>&1 &
fi

exec "$REAL" "$@"
EOF_WRAPPER

chmod 755 "$WRAPPER_PATH"

# Create a default hook only if the user does not already have one.
# This is the file users are supposed to edit.
if [ ! -f "$HOOK_PATH" ]; then
  cat > "$HOOK_PATH" <<'EOF_HOOK'
#!/bin/sh
# reExecute startup hook.
#
# Put your persistent startup commands in this file.
# This script is launched in the background by the MDM wrapper.
#
# IMPORTANT:
# - Do not put long blocking foreground commands here.
# - Use background jobs for daemons/tunnels.
# - Log everything you care about.

LOG="/home/root/reexecute-hook.log"

echo "reExecute hook ran at $(date)" >> "$LOG"

# Example:
# echo "hello from reExecute" >> "$LOG"

exit 0
EOF_HOOK

  chmod 755 "$HOOK_PATH"
fi

# Patch mdm-agent.toml.
# BusyBox-safe: avoid sed -i.
TMP="${MDM_CFG}.reexecute.tmp.$$"

if grep -q '^user_auth_cli[[:space:]]*=' "$MDM_CFG"; then
  awk -v wrapper="$WRAPPER_PATH" '
    /^user_auth_cli[[:space:]]*=/ {
      print "user_auth_cli = \"" wrapper "\""
      next
    }
    { print }
  ' "$MDM_CFG" > "$TMP"
else
  cat "$MDM_CFG" > "$TMP"
  printf '\nuser_auth_cli = "%s"\n' "$WRAPPER_PATH" >> "$TMP"
fi

cat "$TMP" > "$MDM_CFG"
rm -f "$TMP"

sync

# Restart MDM so the hook is tested immediately.
# Do not fail the install if restart is weird; reboot will test it too.
systemctl restart mdm-agent.service 2>/dev/null || true

echo
echo "Installed reExecute."
echo
echo "Current user_auth_cli:"
grep '^user_auth_cli' "$MDM_CFG" || true

echo
echo "Files:"
ls -l "$WRAPPER_PATH" "$HOOK_PATH"

echo
echo "Logs to check:"
echo "  /home/root/reexecute-wrapper.log"
echo "  /home/root/reexecute-hook.log"
REMOTE

echo
echo "Install finished."
echo
echo "To verify:"
echo "  ssh root@${RM_HOST}"
echo "  cat /home/root/reexecute-wrapper.log"
echo "  cat /home/root/reexecute-hook.log"
echo
echo "Edit your persistent startup hook here:"
echo "  /home/root/bin/reexecute-hook.sh"
