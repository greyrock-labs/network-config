# 2026-07-22 — MikroTik fleet: RoMON management overlay

Enabled RoMON on all four MikroTik devices so the whole MikroTik fleet
is reachable from one Winbox session via the RB5009, without needing
direct IP reachability to each box.

## Scope

RoMON is MikroTik-only, so this covers the four RouterOS boxes on the
VLAN 1 / `10.1.0.0/24` mgmt L2 domain:

| Device            | Mgmt IP   | RoMON current-id     |
|-------------------|-----------|----------------------|
| office-rb5009     | 10.1.0.1  | `D0:EA:11:C7:4F:C3`  |
| office-crs309     | 10.1.0.10 | `18:FD:74:B2:D0:67`  |
| game-room-crs309  | 10.1.0.13 | `04:F4:1C:58:22:CD`  |
| garage-crs309     | 10.1.0.16 | `18:FD:74:B2:D0:16`  |

The Ruckus ICX switches cannot run RoMON, but they transparently
forward its L2 frames, so the four MikroTik boxes discover each other
across the mgmt broadcast domain.

## What

- `/tool romon set enabled=yes secret=<shared>` on all four.
- RB5009 only: `/tool romon port add interface=ether1 forbid=yes` —
  keeps RoMON off the WAN so the overlay is not discoverable from the
  ISP side. The CRS309s are all-LAN, left on the default all-ports entry.
- Each box required `/system/device-mode/update romon=yes` plus a
  physical button/power-cycle confirmation (see below).

## Why

Single-pane Winbox management. Connect Winbox to the RB5009 (the box we
already reach on IP), toggle RoMON, and the three CRS309s appear in the
discovered list and are reachable through the overlay — no per-switch
IP session juggling.

**Shared secret** is the security boundary: without it, any MikroTik
dropped onto the mgmt L2 could join the management overlay. Same secret
on all four; committed here as `<REDACTED-ROMON-SECRET>` per the repo
scrub convention.

**WAN forbid on the RB5009** so RoMON never faces the internet.

## device-mode gate (the gotcha)

RouterOS `device-mode` gates RoMON (along with container, traffic-gen,
etc.) behind physical-presence confirmation. Until confirmed, `/tool
romon print` shows `;;; inactivated, not allowed by device-mode` and an
all-zero `id` even though `enabled=yes` is saved. Each box therefore
needed `device-mode update romon=yes` followed by a button press /
power-cycle at the device. Post-confirmation, `device-mode print` shows
`romon: yes` and `/tool romon print` shows a real `current-id`.

Because the confirmation is a reboot and the three CRS309s are spines,
each one briefly blipped the segment behind it during its reboot. Done
deliberately, accepted.

## Repo state

- `routers/office-rb5009/config/running.txt` +
  `snapshots/2026-07-22-post-romon-rb5009.txt`
- `switches/{office,game-room,garage}-crs309/config/running.txt` +
  each `snapshots/2026-07-22-post-romon.txt`
- The RoMON secret is scrubbed to `<REDACTED-ROMON-SECRET>` in every
  committed file. RB5009 `hide-sensitive` export omits the secret line
  entirely; the placeholder is added so the repo records that a secret
  is set.

## Not done / notes

- No custom RoMON IDs — Winbox already shows `/system identity`
  (office-crs309, etc.), so `current-id` = device MAC is sufficient.
- ICX switches are out of scope (not RoMON-capable).
