# Project context for Claude: network-config

## What this repo is

Versioned mirror of the Greyrock Labs switch fleet (currently 6 Ruckus ICX
switches). The repo is the **durable record**; each switch's running-config
is the **live state**. They will drift unless we capture regularly.

See `/Users/todd/src/greyrock-labs/network-config/README.md` for the full
layout and workflow.

## How to orient yourself at the start of a session

1. Read `README.md` for the repo layout and workflow.
2. Read the per-switch `switches/<slot>/README.md` for the box we're working
   on — role, mgmt IP, model, known quirks.
3. Read recent entries in `/changes/` for the *why* behind the current state.
4. Skim `topology/` for site-wide context (VLAN scheme, addressing, uplinks).
5. Check the latest snapshot under `switches/<slot>/config/snapshots/` and the
   current `running.txt` to see actual state.
6. Confirm with the user which switch we're touching before issuing any
   write commands. Serial console goes to a physical cable — there's no
   "wrong host" guard rail.

## Operating principles

- **Never guess CLI commands.** Per user preference, rely on the on-device
  `?` help: type `?` at any prompt for available commands, and `command ?`
  for options. When suggesting a command to the user, frame it as "type
  this, and if it complains, hit `?`" rather than asserting exact syntax.
- **The switch is the source of truth for live state.** If `running.txt` in
  the repo disagrees with what the user describes, the user is probably
  right — capture a fresh snapshot before relying on the repo copy.
- **Capture before and after every change.** Even small changes. Snapshots
  are the rollback path.
- **Document the why, not just the what.** The config diff doesn't say "we
  moved the mgmt VLAN off VLAN 1 because the APs were leaking broadcasts."
  The `changes/<date>.md` file does.
- **Confirm destructive actions.** Reboots, `write memory`, factory resets,
  stack renumbering, and firmware upgrades all deserve explicit confirmation.
  Don't just suggest them in a list of steps.

## Serial console conventions

- Default baud: **9600 8N1, no flow control** (Ruckus ICX factory default).
- Use `picocom` for scripted sessions (in `scripts/`) and either `picocom`
  or `cu` for interactive work.
- The user plugs in a USB-serial cable; the new device appears as
  `/dev/cu.usbserial-XXXX`. Always confirm the path before opening.
- To exit picocom: `Ctrl-A Ctrl-X`.

## Ruckus ICX CLI quick reference (when in doubt, use `?` on the device)

- Modes: user EXEC (`>`) → `enable` → priv EXEC (`#`) → `configure terminal`
  (`(config)#`) → per-context (`(config-if)#`, `(config-vlan-100)#`, etc.)
- `show running-config` — current active config
- `show startup-config` — what's in flash, applied at boot
- `show version` — model, firmware, uptime
- `show ip interface brief` — L3 interfaces / SVIs
- `show vlan brief` — VLANs
- `show interface brief` — port status
- `write memory` — save running to startup
- `end` — back to priv EXEC from any config mode
- `exit` — back to user EXEC

## Workflow per change (the short version)

1. Confirm which switch.
2. `scripts/capture-config.sh <device> <slot> pre-<topic>` → commit snapshot.
3. Make the change (manually on the serial console, with the user typing).
4. `scripts/capture-config.sh <device> <slot> post-<topic>` → updates
   `running.txt` and adds a new snapshot → commit.
5. Write `changes/<date>-<slot>-<topic>.md` with the *why* → commit.

## Things not to do

- Don't put real secrets, PSKs, or community strings in committed config
  files. If a captured config has them, scrub before committing. The
  `.gitignore` excludes `*.secret` etc. for future reference.
- Don't push to a remote unless the user asks.
- Don't rewrite history (force-push, rebase) without explicit permission.
- Don't apply a config file without first verifying it's for the right
  switch. Slot names and hostnames are not always 1:1.
- Don't suggest rebooting a switch as a first step. ICX rarely needs it.
