# Project context for Claude: network-config

## What this repo is

Versioned mirror of the Greyrock Labs switch fleet (currently 6 Ruckus ICX
switches). The repo is the **durable record**; each switch's running-config
is the **live state**. They will drift unless we capture regularly.

See `/Users/todd/src/greyrock-labs/network-config/README.md` for the full
layout and workflow.

## How to orient yourself at the start of a session

1. Read `README.md` for the repo layout and workflow.
2. Read the per-switch `switches/<hostname>/README.md` for the box we're
   working on — role, mgmt IP, model, known quirks.
3. Read recent entries in `/changes/` for the *why* behind the current state.
4. Skim `topology/` for site-wide context (VLAN scheme, addressing, uplinks).
5. Check the latest snapshot under `switches/<hostname>/config/snapshots/`
   and the current `running.txt` to see actual state.
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
- **The repo is a paste-driven workflow, not an automated one.** There's
  no automation in this repo. Captures happen by the user running `show`
  commands on the switch's SSH session and pasting the output back.
  Configs are applied interactively in chunks.

## Serial console conventions

- Default baud: **9600 8N1, no flow control** (Ruckus ICX factory default).
- `picocom` for interactive work, `cu` is also installed.
- The user plugs in a USB-serial cable; the new device appears as
  `/dev/cu.usbserial-XXXX`. Always confirm the path with `ls /dev/cu.*`
  before opening.
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

1. Confirm which switch (hostname) and the change topic.
2. (For non-trivial changes) Capture pre-snapshot: user runs
   `show running-config` on the switch, pastes the output; save to
   `switches/<hostname>/config/snapshots/<date>-pre-<topic>.txt`.
3. Apply the change on the live switch (interactive, in chunks).
4. Capture post-snapshot: paste `show running-config`, save to
   `switches/<hostname>/config/snapshots/<date>-post-<topic>.txt` and
   overwrite `running.txt` (scrubbed of secrets).
5. Document the why in `changes/<date>-<hostname>-<topic>.md`.
6. Commit and push to Forgejo.

## Things not to do

- Don't put real secrets, PSKs, or community strings in committed config
  files. If a captured config has them, scrub before committing. The
  `.gitignore` excludes `*.secret` etc. for future reference.
- Don't push to a remote unless the user asks.
- Don't rewrite history (force-push, rebase) without explicit permission.
- Don't apply a config to a switch without first verifying it's the right
  one. Slot names and hostnames are not always 1:1.
- Don't suggest rebooting a switch as a first step. ICX rarely needs it.
- Don't propose removing a switch from Unleashed (user is explicit about
  this — applied to all 6 switches).
