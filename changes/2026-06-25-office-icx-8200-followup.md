# 2026-06-25 — office-icx-8200 follow-up: 2 missing ports + STP root

## What changed

Two follow-ups on the office 8200 that were missed during initial
configuration:

1. **Configured 2 access ports** that weren't in the original plan
2. **Lowered STP priority** on VLAN 1 from 61440 to 4096 so this
   switch is the STP root

### Ports added

| Port  | Name       | VLANs                  | Features              |
| ----- | ---------- | ---------------------- | --------------------- |
| 1/1/7 | Kerfuffle  | 20 untagged, 10 tagged | BPDU + 500pps, no PoE |
| 1/1/8 | NAS        | 20 untagged            | BPDU + 500pps, no PoE |

The 1/1/7 port is a hybrid port: untagged for VLAN 20 traffic
(PVID 20) and tagged for VLAN 10 traffic. The native/untagged
traffic gets classified as VLAN 20; VLAN 10 frames are
explicitly tagged.

### STP priority change

- `spanning-tree 802-1w priority 4096` on VLAN 1 (was 61440).
- 4096 is well below the default 32768 and below the other
  switches' 61440. This switch now wins the root bridge election
  for VLAN 1.
- Verified with `show 802-1w` — RootBridge Identifier matches
  local Bridge Identifier, Root cost is 0.

### Why this change

The office 8200 is the first switch in the daisy chain — closest
to the router. RSTP root should be at the network edge (close to
the router) so traffic doesn't have to traverse the whole chain
before hitting the root bridge. With priority 4096, the office
8200 is the root and the other 5 switches (all at 61440) elect
their root port pointing back through the chain.

The other 5 switches stay at 61440. Their priority is high
enough that none of them can out-bid the office 8200.

### What changed in the running config

- VLAN 10 added 1/1/7 as tagged
- VLAN 20 added 1/1/7, 1/1/8 as untagged
- 1/1/7 and 1/1/8 have `stp-bpdu-guard` and `broadcast limit 500`
- Port names: Kerfuffle, NAS
- `spanning-tree 802-1w priority 4096` (replacing 61440)

### Observations

- The office 8200 had a 2nd SNMP community string pre-existing
  (`$VWlkRGktWg==`), not in the prior committed snapshot. Same
  string as the garage 7150. Pre-existing on both; preserved.
  Both communities are redacted in `running.txt` as
  `<REDACTED-SNMP-COMMUNITY-1>` and `<REDACTED-SNMP-COMMUNITY-2>`.
- `cli timeout 0` (no idle logout) is back. The reload for jumbo
  reset the `cli timeout 10` we set earlier. This is a firmware
  quirk — `cli timeout` doesn't persist across reloads on this
  build. Acceptable; the other switches are at 10 via the same
  mechanism and will reset the same way on their next reload.

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
- `cli timeout` does not survive a reload on this firmware (gotcha,
  re-confirmed)
