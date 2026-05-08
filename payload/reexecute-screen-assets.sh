#!/bin/sh
# reExecute screen asset payload.
#
# Put replacement images in:
#   /home/root/screen-assets/
#
# Matching filenames will be copied over the stock screen assets.

LOG="/home/root/reexecute-screen-assets.log"
SRC_DIR="/home/root/screen-assets"

log() {
  echo "$(date -Is) $*" >>"$LOG" 2>/dev/null || true
}

copy_if_present() {
  src="$SRC_DIR/$1"
  dst="$2"

  [ -f "$src" ] || return 0

  if [ ! -f "$dst" ]; then
    log "destination missing, skipping: $dst"
    return 0
  fi

  if [ ! -f "$dst.reexecute.bak" ]; then
    cp "$dst" "$dst.reexecute.bak" 2>>"$LOG" || {
      log "backup failed: $dst"
      return 0
    }
  fi

  cp "$src" "$dst" 2>>"$LOG" &&
    log "installed $src -> $dst" ||
    log "install failed $src -> $dst"
}

log "screen asset payload started"

mount -o remount,rw / 2>/dev/null || true
mkdir -p "$SRC_DIR" 2>/dev/null || true

copy_if_present "starting.png" "/usr/share/remarkable/starting.png"
copy_if_present "starting_first.png" "/usr/share/remarkable/starting_first.png"
copy_if_present "poweroff.png" "/usr/share/remarkable/poweroff.png"
copy_if_present "rebooting.png" "/usr/share/remarkable/rebooting.png"
copy_if_present "suspended.png" "/usr/share/remarkable/suspended.png"
copy_if_present "batteryempty.png" "/usr/share/remarkable/batteryempty.png"
copy_if_present "factory.png" "/usr/share/remarkable/factory.png"
copy_if_present "remotewipe.png" "/usr/share/remarkable/remotewipe.png"

copy_if_present "sleep_Illustration_01.png" "/usr/share/remarkable/carousel/sleep_Illustration_01.png"
copy_if_present "sleep_Illustration_02.png" "/usr/share/remarkable/carousel/sleep_Illustration_02.png"
copy_if_present "sleep_Illustration_03.png" "/usr/share/remarkable/carousel/sleep_Illustration_03.png"

copy_if_present "Carousel-01.png" "/home/root/.local/share/remarkable/retail/screensavers/Carousel-01.png"

sync

log "screen asset payload finished"
exit 0
