# 2026-06-24 — garage-icx-8200 initial setup + port/VLAN configuration

## What changed

Took the ICX 8200 from a fresh-out-of-Unleashed (DHCP-driven, no
hostname) state to a static-managed access switch with VLANs and AP
ports.

### Layer 3 / management

- `hostname garage-icx-8200` (was the default `ICX8200-C08ZP Router`)
- Killed DHCP on ve 1 (the firmware order matters — see "Gotchas" below)
- Set static mgmt IP `10.1.0.10/24` on ve 1
- Default route `0.0.0.0/0 → 10.1.0.1`
- NTP servers: time[1-4].internal.greyrock.io
- Timezone: US Eastern with summer-time
- Login banner (single line, `~` is the FastIron-safe delimiter; `^`
  gets mangled by the chat → terminal paste path; `#` is the comment
  character so unusable)
- SSH v2 server enabled, password auth on (Unleashed had already
  loaded the 1Password ED25519 public key, so the key was already
  authorized — confirmed by no-password SSH from the Mac)
- `ip ssh scp enable` (this controls file copy only, NOT remote exec;
  see "Why" below)
- Console timeout 10 min, telnet disabled

### VLANs (Greyrock site scheme)

| VLAN | Name    | Tagged ports                  |
| ---- | ------- | ----------------------------- |
| 1    | DEFAULT-VLAN (mgmt) | all ports, untagged (native) |
| 10   | Internal | 1/1/1–1/1/5, 1/2/1, 1/2/2  |
| 20   | Servers  | 1/2/1, 1/2/2 only          |
| 4000 | Guest    | 1/1/1–1/1/5, 1/2/1, 1/2/2  |

APs get tagged traffic for 10 + 4000, untagged for 1 (mgmt). Servers
VLAN does not touch the APs.

### Ports (1/1/x APs, 1/2/x trunks)

| Port | Role               | Name              | Features                     |
| ---- | ------------------ | ----------------- | ---------------------------- |
| 1/1/1 | Garage Rear AP    | Garage-Rear-AP    | PoE, BPDU guard, storm ctrl  |
| 1/1/2 | Garage Side AP    | Garage-Side-AP    | PoE, BPDU guard, storm ctrl  |
| 1/1/3 | Side Drive AP     | Side-Drive-AP     | PoE, BPDU guard, storm ctrl  |
| 1/1/4 | Garage AP         | Garage-AP         | PoE, BPDU guard, storm ctrl  |
| 1/1/5 | Kitchen AP        | Kitchen-AP        | PoE, BPDU guard, storm ctrl  |
| 1/2/1 | Garage 7150 down  | Garage-7150       | trunk, no PoE                |
| 1/2/2 | Game Room 8200 up | GameRoom-8200     | trunk, no PoE                |

`broadcast limit 500` = 500 pps storm-control on broadcast (access
ports). Not enabled on trunks — they have to handle real traffic.

## Why each decision

- **Static IP, not DHCP**: The 8200 was getting `10.1.0.114` from
  Unleashed/DHCP. We want a predictable, documented address.
- **Native VLAN 1, not a dedicated mgmt VLAN**: Site uses VLAN 1 for
  mgmt across the board. Simpler for the home network.
- **Storm control on APs, not trunks**: APs shouldn't be generating
  broadcast storms; trunks can.
- **BPDU guard on APs, not trunks**: APs don't run STP. If they
  receive a BPDU, something is wrong and we want the port to err-disable.
- **16-char port names**: FastIron's `port-name` field truncates at 16
  characters on this firmware. Names chosen to fit.

## Topology

This switch is the second-to-last hop in the home daisy chain:

```
router → office 8200 → office 7150 → game room 8200 →
  game room 7150 → garage 8200 (this) → garage 7150
```

The 8200 has 2 SFP+ ports; both are used for the chain.

## Gotchas (firmware 10.0.10g_cd6T253 / Unleashed T-series)

These are the FastIron behaviors I hit that aren't documented clearly:

- **No `ip domain-name` command.** The DNS search domain lives only
  under `ip dns domain-list`. The hostname + domain-list is the FQDN.
- **No `ntp prefer` keyword.** The `ntp` config context has `server`
  but not `prefer`. All four NTP servers are equal.
- **DHCP client removal order matters.** You must run
  `ip dhcp-client disable` (global) BEFORE
  `no ip dhcp-client ve default`, otherwise the firmware refuses with
  "cannot remove the DHCP-Client on ve default when DHCP-Client is
  enabled globally." AND the static `ip address` on the VE is rejected
  with "Error: DHCP client is running on VE default, disable it by
  'no ip dhcp-client ve default' before configuring the static IP
  address" if you try to set it while DHCP is still active.
- **`clock timezone us Eastern` is the right form.** Capital E,
  space-separated. `us-eastern` is accepted but the running config
  shows it as `us Eastern` either way.
- **VLAN port assignment goes through `vlan <id>` context, not the
  interface context.** Inside `vlan <id>`, use `tagged ethe X/Y/Z` or
  `untagged ethe X/Y/Z`. The `tagged`/`untagged` keywords under
  `interface ethernet` don't exist on this firmware.
- **`stp-bpdu-guard` (port context), not `spanning-tree bpdu-guard`.**
  Both forms may be accepted but the help under `interface ethernet`
  shows `stp-bpdu-guard`.
- **Storm control: `broadcast limit <pps>`, not `broadcast <pps>`.**
  The `limit` keyword is required.
- **`port-name` is 16 characters max** on this firmware (matches the
  display column width).
- **`ip ssh scp enable` only enables file copy.** It does NOT enable
  remote command execution. The error "SCP access and remote command
  executions are denied" is a single message that covers both; fixing
  one doesn't fix the other. The right knob for remote exec is
  elsewhere in the firmware and not yet identified (TODO).
- **Banner delimiter `^` is fragile in chat paste** because the
  terminal pipeline renders `^` as ASCII ETX (0x03) sometimes. Single-
  line banners with `^` work; multi-line banners get `^C` characters
  inserted between lines. The current banner is on a single line, so
  it's fine.

## Still TODO

- RSTP priority (per the user's notes — unconfirmed as needed yet)
- IGMP/MLD snooping for multicast (also from user's notes)
- Dynamic PoE allocation (from user's notes)
- Jumbo frames (from user's notes)
- Enable remote command execution over SSH (to allow
  `scripts/capture-config.sh` to work via SSH, not just paste)
- Banner: ideally re-do as a clean multi-line text, but the current
  single-line works
- Push repo to git.greyrock.io (user needs to create the remote repo
  first; remote is already configured as `origin`)
