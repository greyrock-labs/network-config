# 2026-06-25 — game-room-icx-7150 initial setup + port/VLAN configuration

## What changed

Took the game-room 7150 from DHCP-driven to a fully-configured
access switch with the same feature set as the other 3 already
configured.

### Hardware

- Model: ICX7150-C12-POE (12 PoE ports + 2× 1G copper + 2× 10G SFP+)
- Firmware: 10.0.10g_cd6T213 (same as garage-icx-7150)
- Serial: FEK3850Q0W1
- License: 2X10GR
- 1/3/1 was already UP at 10G (uplink to game-room-icx-8200 — chain
  toward the router). 1/3/2 (the second SFP+) is unused.

### Layer 3 / management

- Hostname `game-room-icx-7150`
- Killed DHCP on ve 1 (same order: global disable → remove from VE
  → set static IP)
- Static mgmt IP `10.1.0.13/24` on ve 1
- Default route `0.0.0.0/0 → 10.1.0.1`
- NTP servers: time[1-4].internal.greyrock.io (no `prefer`)
- Timezone: US Eastern with summer-time
- Login banner (single line)
- SSH v2 (already enabled; password auth on)
- `console timeout 10` (10 min)

### VLANs (Greyrock site scheme)

| VLAN | Name    | Tagged ports           | Untagged ports         |
| ---- | ------- | ---------------------- | ---------------------- |
| 1    | mgmt    | (none; native)         | all (default)          |
| 10   | Internal| 1/3/1 (trunk)         | 1/1/1, 1/1/2, 1/1/3   |
| 20   | Servers | 1/3/1 (trunk)         | (none)                 |
| 4000 | Guest   | 1/3/1 (trunk)         | (none)                 |

### Ports

| Port  | Name          | What plugs in            | PoE | BPDU | Storm ctrl |
| ----- | ------------- | ------------------------ | --- | ---- | ---------- |
| 1/1/1 | SolarEdge     | SolarEdge Inverter       | no  | yes  | 500 pps    |
| 1/1/2 | Zigbee        | Zigbee Coordinator       | no  | yes  | 500 pps    |
| 1/1/3 | Z-Wave        | Z-Wave Coordinator       | no  | yes  | 500 pps    |
| 1/1/4-1/1/12 | _(unused)_ | —                   | (default) | (default) | (default) |
| 1/2/1, 1/2/2 | _(unused)_ | —                    | (default) | (default) | (default) |
| 1/3/1 | GameRoom-8200 | Trunk uplink to 8200     | no  | no   | off        |
| 1/3/2 | _(unused)_   | —                        | no  | no   | off        |

### Features (matches the other 3 configured switches)

- `jumbo` (MTU 10200, requires reload — done)
- `inline power allocation dynamic all`
- RSTP 802-1w on VLAN 1, priority 61440 (not root)
- IGMP/MLD snooping on VLAN 10 (IGMPv3, MLDv2, fast-convergence on both)
- `ipv6 mld version 2` (global)

## Port naming note

Initial port names (`SolarEdge-Inverter`, `Zigbee-Coord`, `ZWave-Coord`,
`GameRoom-8200`) were too long for the 16-char limit on `port-name`
on this firmware — `SolarEdge-Inverter` (17 chars) was getting
truncated to `SolarEdge-Inver` at storage. The other three were
within limits but felt noisy. Final names:

- 1/1/1: `SolarEdge`
- 1/1/2: `Zigbee`
- 1/1/3: `Z-Wave`
- 1/3/1: `GameRoom-8200`

## Gotchas (re-confirmed)

- 16-char hard limit on `port-name` field on this firmware
- `no ip telnet server` not needed (telnet off by default)
- `ntp prefer` doesn't exist
- `show ip interface brief` doesn't exist (use `show running-config`
  to see IP info)
- `jumbo` requires reload to take effect
- `spanning-tree 802-1w` must be enabled before `spanning-tree 802-1w priority`
- VLAN 1 tagging on trunks is unnecessary (VLAN 1 is the default
  untagged VLAN on every port)

## Still TODO

- Connect uplink cable from game-room-icx-7150 1/3/1 to
  game-room-icx-8200 1/2/1 (the 8200 side is configured, this 7150
  side is configured, just need the physical cable)
- Once both ends are physically connected, end-to-end daisy chain
  through this hop is verified
