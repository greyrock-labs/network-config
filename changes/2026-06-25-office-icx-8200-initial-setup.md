# 2026-06-25 — office-icx-8200 initial setup + port/VLAN configuration

## What changed

Took the office 8200 from DHCP-driven to a fully-configured
access switch with the same feature set as the other 4 already
configured. This is the FIRST switch in the daisy chain — its
1/2/2 uplinks directly to the router.

### Hardware

- Model: ICX8200-C08ZP-POE (8 PoE ports + 2× 25G SFP+ module)
- Firmware: 10.0.10g_cd6T253
- Serial: FNR4337U0LT
- License: 2X25G
- 1/2/2 was already UP at 10G (uplink to the router).
- 1/2/1 is DOWN — downlink to office-icx-7150, no cable yet.

### Layer 3 / management

- Hostname `office-icx-8200`
- Killed DHCP on ve 1
- Static mgmt IP `10.1.0.14/24` on ve 1
- Default route `0.0.0.0/0 → 10.1.0.1`
- NTP servers: time[1-4].internal.greyrock.io
- Timezone: US Eastern with summer-time
- Login banner (single line)
- SSH v2 (already enabled; password auth on)
- `console timeout 10` (10 min)

### VLANs (Greyrock site scheme)

| VLAN | Name    | Tagged ports                          | Untagged ports |
| ---- | ------- | ------------------------------------- | -------------- |
| 1    | mgmt    | (none; native)                        | all (default)  |
| 10   | Internal| 1/1/1, 1/1/5 (APs), 1/2/1, 1/2/2 (trunks) | (none)   |
| 20   | Servers | 1/2/1, 1/2/2 only                    | (none)         |
| 4000 | Guest   | 1/1/1, 1/1/5 (APs), 1/2/1, 1/2/2 (trunks) | (none)   |

### Ports

| Port  | Name          | What plugs in              | PoE | BPDU | Storm ctrl |
| ----- | ------------- | -------------------------- | --- | ---- | ---------- |
| 1/1/1 | UH-AP         | Upstairs Hallway AP        | yes | yes  | 500 pps    |
| 1/1/2-1/1/4 | _(unused)_ | —                       | (default) | (default) | (default) |
| 1/1/5 | Office-AP     | Office AP                  | yes | yes  | 500 pps    |
| 1/1/6-1/1/8 | _(unused)_ | —                       | (default) | (default) | (default) |
| 1/2/1 | Office-7150   | Trunk downlink to 7150     | no  | no   | off        |
| 1/2/2 | Router        | Trunk uplink to router     | no  | no   | off        |

### Features (matches the other 4 configured switches)

- `jumbo` (MTU 10200, requires reload — done)
- `inline power allocation dynamic all`
- RSTP 802-1w on VLAN 1, priority 61440 (not root; the office 8200
  is closest to the router, so it should be the STP root — but the
  user direction is to keep this consistent at 61440 for now. The
  root can be moved later if RSTP convergence requires it.)
- IGMP/MLD snooping on VLAN 10 (IGMPv3, MLDv2, fast-convergence on both)
- `ipv6 mld version 2` (global)

## Gotchas (re-confirmed on this build)

- 16-char hard limit on `port-name` field on this firmware
- `no ip telnet server` not needed (telnet off by default)
- `ntp prefer` doesn't exist
- `show ip interface brief` doesn't exist
- `jumbo` requires reload to take effect
- `spanning-tree 802-1w` must be enabled before
  `spanning-tree 802-1w priority`
- VLAN 1 tagging on trunks is unnecessary (VLAN 1 is the default
  untagged VLAN on every port)
- Serial cable was unplugged by the time the reload was issued;
  the post-reload verification was done over SSH from the Mac

## Still TODO

- Connect uplink cable from office-icx-8200 1/2/1 to
  office-icx-7150 (the 7150 isn't configured yet — it's the last
  one in the chain)
- Once both ends are connected, the chain from the router all the
  way to the garage is end-to-end live
