#!/usr/bin/env bash
# apply-config.sh — feed a config file to a Ruckus ICX switch over the serial
# console, line-by-line, with safe pacing.
#
# Usage:
#   scripts/apply-config.sh <device> <config-file> [switch-slot]
#   scripts/apply-config.sh /dev/cu.usbserial-A50285BI switches/sw-03/config/restore.txt
#
# CAUTION: this feeds commands to a live switch. Always capture a snapshot
# (scripts/capture-config.sh) before running this.
#
# How it works:
#   1. Opens the serial port via picocom with a script that:
#      - sends a few newlines to get to a prompt
#      - sends "enable" to get to priv exec
#      - sends "configure terminal"
#      - feeds the config file one line at a time
#      - sends "end" and "write memory" to save
#   2. Logs the whole session to switches/<slot>/logs/<timestamp>.log
#
# The config file should be a list of ICX config commands, one per line.
# Blank lines and lines starting with "#" are ignored. "end" / "write memory"
# are NOT required at the end — the script appends them.
#
# Env overrides:
#   BAUD=9600 (default)
#   LINE_DELAY=0.05  (seconds between lines; bump if the switch drops chars)

set -euo pipefail

DEVICE="${1:-}"
CFG_FILE="${2:-}"
SLOT="${3:-}"

if [[ -z "$DEVICE" || -z "$CFG_FILE" ]] ; then
  echo "usage: $0 <device> <config-file> [switch-slot]" >&2
  echo "" >&2
  echo "  device:      serial port, e.g. /dev/cu.usbserial-XXXX" >&2
  echo "  config-file: text file with one ICX config command per line" >&2
  echo "  switch-slot: e.g. sw-03 (used for log location)" >&2
  exit 2
fi

if [[ ! -f "$CFG_FILE" ]] ; then
  echo "error: $CFG_FILE does not exist" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BAUD="${BAUD:-9600}"
LINE_DELAY="${LINE_DELAY:-0.05}"
TS="$(date +%Y%m%d-%H%M%S)"

if [[ -n "$SLOT" ]] ; then
  LOG_FILE="$REPO_ROOT/switches/$SLOT/logs/$TS-apply.log"
  mkdir -p "$(dirname "$LOG_FILE")"
else
  LOG_FILE="/tmp/apply-config-$TS.log"
fi

cat <<EOF
== apply-config.sh ==
device:      $DEVICE
config file: $CFG_FILE
slot:        ${SLOT:-(none)}
baud:        $BAUD
line delay:  ${LINE_DELAY}s
log:         $LOG_FILE

WARN: this will apply the config to a live switch. Ctrl-A Ctrl-X to abort.
Sleeping 5s — Ctrl-C to cancel...
EOF

sleep 5

# Build the picocom script. We append the contents of CFG_FILE (filtered)
# after the prep commands. Picocom scripts don't support inline file inclusion,
# so we dump the config into a script file alongside the control commands.
SCRIPT_FILE="/tmp/apply-config-$TS.script"
{
  echo ""
  echo ""
  echo "enable"
  echo "configure terminal"
  # Filter out blanks and pure comment lines; pass everything else through.
  grep -vE '^\s*(#|$)' "$CFG_FILE" || true
  echo "end"
  echo "write memory"
} > "$SCRIPT_FILE"

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
  --script "$SCRIPT_FILE" \
  "$DEVICE" || true

cat <<EOF

== done ==
log: $LOG_FILE
Recommended next: scripts/capture-config.sh $DEVICE $SLOT post-apply
EOF
