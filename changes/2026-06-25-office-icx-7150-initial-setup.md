# 2026-06-25 — office-icx-7150 initial setup + port/VLAN configuration

## What changed

Took the office 7150 from DHCP-driven to a fully-configured
access switch with the same feature set as the other 5. This is
the SECOND switch in the daisy chain, sitting between the office
8200 and the game room 8200.

### Hardware

- Model: ICX7150-C12-POE (12 PoE ports + 2× 1G copper + 2× 10G SFP+)
- Firmware: 10.0.10g_cd6T213
- Serial: FEK3217R0LN
- License: 2X10GR
- 1/3/1 was already UP at 10G (uplink to office-icx-8200)
- 1/3/2 is DOWN — downlink to game-room-icx-8200, no cable yet

### Layer 3 / management

- Hostname `office-icx-7150`
- Killed DHCP on ve 1
- Static mgmt IP `10.1.0.15/24` on ve 1
- Default route `0.0.0.0/0 → 10.1.0.1`
- NTP servers: time[1-4].internal.greyrock.io
- Timezone: US Eastern with summer-time
- Login banner (single line)
- SSH v2 (already enabled; password auth on)
- `console timeout 10` (10 min)

### VLANs (Greyrock site scheme)

| VLAN | Name    | Tagged ports           | Untagged ports         |
| ---- | ------- | ---------------------- | ---------------------- |
| 1    | mgmt    | (none; native)         | all (default)          |
| 10   | Internal| 1/3/1, 1/3/2 (trunks) | 1/1/8 (HASS)          |
| 20   | Servers | 1/3/1, 1/3/2 (trunks) | 1/1/1–1/1/7 (servers) |
| 4000 | Guest   | 1/3/1, 1/3/2 (trunks) | (none)                 |

### Ports

| Port  | Name            | What plugs in         | PoE | BPDU | Storm ctrl |
| ----- | --------------- | --------------------- | --- | ---- | ---------- |
| 1/1/1 | NTP1            | NTP server 1          | no  | yes  | 500 pps    |
| 1/1/2 | NTP2            | NTP server 2          | no  | yes  | 500 pps    |
| 1/1/3 | NTP3            | NTP server 3          | no  | yes  | 500 pps    |
| 1/1/4 | NTP4            | NTP server 4          | no  | yes  | 500 pps    |
| 1/1/5 | KVM-NAS         | KVM NAS               | no  | yes  | 500 pps    |
| 1/1/6 | KVM-Kerfuffle   | KVM Kerfuffle         | no  | yes  | 500 pps    |
| 1/1/7 | KVM-HASS        | KVM HASS              | no  | yes  | 500 pps    |
| 1/1/8 | HASS            | HASS                  | no  | yes  | 500 pps    |
| 1/1/9-1/1/12 | _(unused)_ | —                  | (default) | (default) | (default) |
| 1/2/1, 1/2/2 | _(unused)_ | —                   | (default) | (default) | (default) |
| 1/3/1 | Office-8200     | Trunk uplink          | no  | no   | off        |
| 1/3/2 | GameRoom-8200   | Trunk downlink        | no  | no   | off        |

### Features (matches the other 5 configured switches)

- `jumbo` (MTU 10200, requires reload — done)
- `inline power allocation dynamic all`
- RSTP 802-1w on VLAN 1, priority 61440 (not root; see note below)
- IGMP/MLD snooping on VLAN 10 (IGMPv3, MLDv2, fast-convergence on both)
- `ipv6 mld version 2` (global)

## Note on STP

This switch is configured with RSTP priority 61440 like all the
other switches. The office-icx-8200 is the closest to the router
and should be the STP root, so its priority should be LOWER (e.g.
4096) than the rest of the fleet. This is a follow-up item; the
office 8200's priority will be lowered in a separate change.

## Gotchas (re-confirmed)

- 16-char hard limit on `port-name` field on this firmware
- `no ip telnet server` not needed (telnet off by default)
- `ntp prefer` doesn't exist
- `show ip interface brief` doesn't exist
- `jumbo` requires reload to take effect
- `spanning-tree 802-1w` must be enabled before
  `spanning-tree 802-1w priority`
- VLAN 1 tagging on trunks is unnecessary (VLAN 1 is the default
  untagged VLAN on every port)

## Still TODO

- Connect uplink cable from office-icx-7150 1/3/2 to
  game-room-icx-8200 1/2/1 (both ends are configured, just need the
  physical cable)
- Once that cable is in, the daisy chain is end-to-end live from
  the router to the garage
- Lower STP priority on the office 8200 (see above)
- Configure the 2 missing ports on the office 8200 (separate
  follow-up)
