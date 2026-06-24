#!/usr/bin/env bash
# capture-config.sh — pull running-config (and/or startup-config) from a
# Ruckus ICX switch over a serial console, save to a snapshot file.
#
# Usage:
#   scripts/capture-config.sh <device> <switch-slot> [label]
#   scripts/capture-config.sh /dev/cu.usbserial-A50285BI sw-03
#   scripts/capture-config.sh /dev/cu.usbserial-A50285BI sw-03 pre-vlan-changes
#
# Defaults to 9600 8N1 (Ruckus ICX factory default). Override with env vars:
#   BAUD=115200 scripts/capture-config.sh /dev/tty.usbserial-XXXX sw-01
#
# The script:
#   1. Opens the serial port
#   2. Sends a few newlines + the enable command ("en\n") to get to priv exec
#   3. Sends "show running-config" / "show startup-config" / "show version"
#   4. Logs the entire session to switches/<slot>/logs/<timestamp>.log
#   5. Saves running-config to switches/<slot>/config/running.txt
#   6. Saves startup-config to switches/<slot>/config/startup.txt
#   7. Optionally saves a labeled snapshot under config/snapshots/

set -euo pipefail

DEVICE="${1:-}"
SLOT="${2:-}"
LABEL="${3:-}"

if [[ -z "$DEVICE" || -z "$SLOT" ]] ; then
  echo "usage: $0 <device> <switch-slot> [label]" >&2
  echo "  device:     e.g. /dev/cu.usbserial-A50285BI" >&2
  echo "  switch-slot: e.g. sw-03" >&2
  echo "  label:      optional tag for the snapshot, e.g. pre-vlan-changes" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLOT_DIR="$REPO_ROOT/switches/$SLOT"
LOG_DIR="$SLOT_DIR/logs"
CFG_DIR="$SLOT_DIR/config"
SNAP_DIR="$CFG_DIR/snapshots"

if [[ ! -d "$SLOT_DIR" ]] ; then
  echo "error: $SLOT_DIR does not exist" >&2
  exit 1
fi

mkdir -p "$LOG_DIR" "$SNAP_DIR"

BAUD="${BAUD:-9600}"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/$TS.log"
SNAP_TAG="${LABEL:-$TS}"
SNAP_FILE="$SNAP_DIR/${TS}-${SNAP_TAG}.txt"

# Picocom invocation:
#   -b BAUD : baud rate
#   -q      : quiet (no local echo of received chars to terminal — we want the log file)
#   -r      : capture to file
#   -l      : capture to script (commands to send on connect)
#   --omap crcrlf / --imap nolcrlf : keep line endings predictable
#   -e      : enable local echo so we see what we type
#   -x 0    : don't send init string (we drive the session ourselves)

SCRIPT="$LOG_DIR/$TS.script"
cat > "$SCRIPT" <<'EOF'

enable
show running-config
show startup-config
show version
exit
EOF

# Print a banner so the user knows what's happening.
cat <<EOF
== capture-config.sh ==
device:     $DEVICE
slot:       $SLOT
label:      $LABEL
baud:       $BAUD
log:        $LOG_FILE
snapshot:   $SNAP_FILE
repo root:  $REPO_ROOT

Press Ctrl-A Ctrl-X to exit picocom when done (or wait — it will time out).
EOF

# Run picocom. It will:
#   - open the port
#   - run the script (send the commands)
#   - capture everything to the log file
#   - exit when the script is exhausted, or Ctrl-A Ctrl-X
picocom \
  --baud "$BAUD" \
  --databits 8 \
  --parity n \
  --stopbits 1 \
  --flow n \
  --quiet \
  --no-init \
  --omap crcrlf \
  --imap nolcrlf \
  --echo \
  --logfile "$LOG_FILE" \
  --script "$SCRIPT" \
  "$DEVICE" || true

# Extract the running-config block from the log into a clean text file.
# We grab everything between the literal "show running-config" prompt and the
# next prompt (typically ending with "#" or ">" after the next "show" command
# or "exit"). This is intentionally lenient — we'll tidy it up at commit time.
if [[ -f "$LOG_FILE" ]] ; then
  # Running config
  awk '
    /show running-config/ { capture=1; next }
    capture && /^[A-Za-z0-9].*[#>] *$/ && !/show running-config/ { capture=0 }
    capture { print }
  ' "$LOG_FILE" > "$CFG_DIR/running.txt" || true

  # Startup config
  awk '
    /show startup-config/ { capture=1; next }
    capture && /^[A-Za-z0-9].*[#>] *$/ && !/show startup-config/ { capture=0 }
    capture { print }
  ' "$LOG_FILE" > "$CFG_DIR/startup.txt" || true

  # Version info
  awk '
    /show version/ { capture=1 }
    capture { print }
    capture && /^#/ && NR > 5 { if (++count > 60) { capture=0; count=0 } }
  ' "$LOG_FILE" > "$CFG_DIR/version.txt" || true

  # Also save a labeled snapshot of the running config
  cp "$CFG_DIR/running.txt" "$SNAP_FILE" 2>/dev/null || true

  cat <<EOF

== done ==
log:        $LOG_FILE
running:    $CFG_DIR/running.txt
startup:    $CFG_DIR/startup.txt
snapshot:   $SNAP_FILE

Next steps:
  cd $REPO_ROOT
  git add switches/$SLOT
  git commit -m "capture: $SLOT $SNAP_TAG"
EOF
else
  echo "error: log file was not created — check that $DEVICE is connected" >&2
  exit 1
fi
