# 2026-06-24 — game-room-icx-8200 initial setup + port/VLAN configuration

## What changed

Took the game-room 8200 from DHCP-driven to a fully-configured
access switch with the same feature set as the garage 8200.

### Hardware

- Model: ICX8200-C08ZP-POE (8 PoE ports + 2× 25G SFP+ module)
- Firmware: 10.0.10g_cd6T253 (same as garage-icx-8200)
- Serial: FNR4329U04W
- License: 2X25GR
- 1/2/2 was already UP at 10G (uplink to office-icx-7150 — chain
  toward the router). 1/2/1 (downlink to game-room-icx-7150) is
  DOWN — no cable yet.

### Layer 3 / management

- Hostname `game-room-icx-8200`
- Killed DHCP on ve 1 (same order: global disable → remove from VE
  → set static IP)
- Static mgmt IP `10.1.0.12/24` on ve 1
- Default route `0.0.0.0/0 → 10.1.0.1`
- NTP servers: time[1-4].internal.greyrock.io (no `prefer` —
  doesn't exist on this firmware)
- Timezone: US Eastern with summer-time
- Login banner (single line)
- SSH v2 (already enabled; password auth on)
- `console timeout 10` (10 min)

### VLANs (Greyrock site scheme)

| VLAN | Name    | Tagged ports                  | Untagged ports   |
| ---- | ------- | ----------------------------- | ---------------- |
| 1    | mgmt    | 1/1/7, 1/1/8 (APs)           | 1/2/1, 1/2/2 (trunks, default) |
| 10   | Internal| 1/1/7, 1/1/8 (APs), 1/2/1, 1/2/2 (trunks) | 1/1/1, 1/1/5 (desktops) |
| 20   | Servers | 1/2/1, 1/2/2 only            | (none)           |
| 4000 | Guest   | 1/1/7, 1/1/8 (APs), 1/2/1, 1/2/2 (trunks) | (none) |

### Ports

| Port  | Name            | What plugs in      | PoE | BPDU | Storm ctrl |
| ----- | --------------- | ------------------ | --- | ---- | ---------- |
| 1/1/1 | Andys-Desktop   | Andy's desktop     | no  | yes  | 500 pps    |
| 1/1/2 | _(unused)_     | —                  | no  | no   | off        |
| 1/1/3 | _(unused)_     | —                  | no  | no   | off        |
| 1/1/4 | _(unused)_     | —                  | no  | no   | off        |
| 1/1/5 | Todds-Desktop   | Todd's desktop     | no  | yes  | 500 pps    |
| 1/1/6 | _(unused)_     | —                  | no  | no   | off        |
| 1/1/7 | Game-Room-AP    | Game Room AP       | yes | yes  | 500 pps    |
| 1/1/8 | Living-Room-AP  | Living Room AP     | yes | yes  | 500 pps    |
| 1/2/1 | GameRoom-7150   | Trunk downlink     | no  | no   | off        |
| 1/2/2 | Office-7150     | Trunk uplink       | no  | no   | off        |

### Features (matches the garage 8200)

- `jumbo` (MTU 10200, requires reload — done)
- `inline power allocation dynamic all`
- RSTP 802-1w on VLAN 1, priority 61440 (not root)
- IGMP/MLD snooping on VLAN 10 (IGMPv3, MLDv2, fast-convergence on both)
- `ipv6 mld version 2` (global)

## Gotchas (re-confirmed on this build)

- `no ip telnet server` not needed (telnet is off by default)
- `ntp prefer` doesn't exist
- `show ip interface brief` doesn't exist (use `show running-config`
  to see IP info, or just `show ip interface` no brief)
- `jumbo` requires reload to take effect
- `spanning-tree 802-1w` must be enabled before `spanning-tree 802-1w priority`
- VLAN 1 tagging on trunks is unnecessary (VLAN 1 is the default
  untagged VLAN on every port)

## Still TODO

- Connect uplink cable from game-room-icx-8200 1/2/1 to
  game-room-icx-7150 (one side already there on this 8200)
- Verify the daisy chain remains end-to-end after that cable
  connection (it should be no-op since both ends are configured)
