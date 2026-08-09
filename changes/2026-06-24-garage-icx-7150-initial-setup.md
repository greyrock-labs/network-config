# 2026-06-24 — garage-icx-7150 initial setup

## What changed

Took the ICX 7150 from a DHCP-driven fresh state to a static-managed
access switch (mgmt layer only — port/VLAN config is a follow-up).

### Hardware

- Model: ICX7150-C12-POE (12-port PoE + 2× 1G copper module +
  2× 10G SFP+ module)
- Firmware: 10.0.10g_cd6**T213** (different minor build than the
  garage 8200's T253, but same family)
- Serial: FEK3825R029
- License: 2X10GR
- Modules:
  - 1/1/x = 12× PoE+ ports
  - 1/2/x = 2× 1G copper
  - 1/3/x = 2× 10G SFP+ (stacking ports by default)

### Layer 3 / management

- `hostname garage-icx-7150`
- Killed DHCP on ve 1 (same order as the 8200: global disable → remove
  from VE → set static IP)
- Static mgmt IP `10.1.0.11/24` on ve 1
- Default route `0.0.0.0/0 → 10.1.0.1`
- NTP: time[1-4].internal.greyrock.io (no `prefer` — see gotchas)
- Timezone: US Eastern with summer-time
- Login banner (single line, same approach as the 8200)
- SSH v2 already enabled; `ip ssh enable` returned "SSH already
  enabled" so it was on by default
- `ip ssh password-authentication yes` (Unleashed pre-loaded the
  1Password ED25519 key, confirmed by no-password SSH)
- `console timeout 10` (10 min, matches the 8200)

### What's preserved from the original (unmodified)

- `manager registrar` — kept as-is
- `aaa authentication login default local` and
  `aaa authentication web-server default local`
- `logging host 10.1.10.7 udp-port 6514` (syslog target)
- `snmp-server community 2 ... ro` (kept as-is)
- `username admin password 1 ...` (Unleashed-created)
- `global-stp` and `vlan 1 ... spanning-tree`

## Gotchas (new with this build)

- **`no ip telnet server` errors with "Invalid input"** on this
  7150 build (T213). It's not in the syntax tree. Telnet is off by
  default on Ruckus FastIron, so the line is a no-op anyway — but
  this means the 8200's `no ip telnet server` line is build-specific,
  not universal.
- **CLI timeout: 10 min** was already set on this switch. (Default
  is 0 / no timeout; the 8200 had `cli timeout 0` and we never
  changed it; the 7150 has 10. Difference is build- or
  pre-staging-dependent, not something we configured.)
- **`prefer` keyword still doesn't exist** under `ntp` config on
  this build. Confirmed across both firmware builds.
- **SSH was already enabled** at the start of the session. Unleashed
  turns it on during adoption.

## Still TODO

- Port and VLAN configuration (per user direction, deferred to a
  follow-up session)
- Push to Forgejo (covered in this commit)
