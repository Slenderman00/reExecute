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
require_cmd scp

if [ ! -d payload ]; then
  echo "error: payload directory not found" >&2
  exit 1
fi

if ! find payload -type f | grep -q .; then
  echo "error: payload directory is empty" >&2
  exit 1
fi

if [ ! -f payload/reexecute-user-authenticator-cli ]; then
  echo "error: missing payload/reexecute-user-authenticator-cli" >&2
  exit 1
fi

if [ ! -f payload/reexecute-hook.sh ]; then
  echo "error: missing payload/reexecute-hook.sh" >&2
  exit 1
fi

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
echo "Creating remote bin directory..."
remote_sh "mkdir -p '$REMOTE_BIN_DIR'"

echo
echo "Uploading payload files..."
sshpass -p "$RM_PASS" scp "${SSH_OPTS[@]}" payload/* \
  "${RM_USER}@${RM_HOST}:${REMOTE_BIN_DIR}/"

echo
echo "Installing persistent MDM hook..."

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

if [ ! -f "$WRAPPER_PATH" ]; then
  echo "error: wrapper was not uploaded: $WRAPPER_PATH" >&2
  exit 1
fi

if [ ! -f "$HOOK_PATH" ]; then
  echo "error: hook was not uploaded: $HOOK_PATH" >&2
  exit 1
fi

chmod 755 "$REMOTE_BIN_DIR"/reexecute-* 2>/dev/null || true

# Keep the first backup. Never overwrite a known-good original.
if [ ! -f "$MDM_CFG_BACKUP" ]; then
  cp "$MDM_CFG" "$MDM_CFG_BACKUP"
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
ls -l "$REMOTE_BIN_DIR"/reexecute-* 2>/dev/null || true

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
