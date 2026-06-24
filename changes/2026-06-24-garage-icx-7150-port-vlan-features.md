# 2026-06-24 — garage-icx-7150 port/VLAN configuration + 8200 feature parity

## What changed

Configured the 7150's ports, VLANs, and applied the same feature set
that the 8200 has (jumbo, RSTP, IGMP/MLD, dynamic PoE).

### VLANs (Greyrock site scheme)

| VLAN | Name    | Tagged ports           | Untagged ports         |
| ---- | ------- | ---------------------- | ---------------------- |
| 1    | mgmt    | (none; native)         | all 1/1/x, 1/2/x, 1/3/x (default) |
| 10   | Internal| 1/3/1 (trunk)         | 1/1/1, 1/1/2, 1/1/3, 1/1/4, 1/1/6 |
| 20   | Servers | 1/3/1 (trunk)         | (none)                 |
| 4000 | Guest   | 1/3/1 (trunk)         | (none)                 |

### Ports

| Port  | Name            | What plugs in              | Features                     |
| ----- | --------------- | -------------------------- | ---------------------------- |
| 1/1/1 | Porch-Doorbell  | Courtyard porch doorbell  | PoE, BPDU guard, 500pps      |
| 1/1/2 | Garage-Todd     | Garage (Todd)             | PoE, BPDU guard, 500pps      |
| 1/1/3 | Rear-Driveway   | Rear driveway              | PoE, BPDU guard, 500pps      |
| 1/1/4 | Rear-Yard       | Rear driveway yard         | PoE, BPDU guard, 500pps      |
| 1/1/5 | _(unused)_     | —                          | (default)                    |
| 1/1/6 | Garage-Andy     | Garage (Andy)             | PoE, BPDU guard, 500pps      |
| 1/1/7-1/1/12 | _(unused)_ | —                       | (default)                    |
| 1/2/1, 1/2/2 | _(unused)_ | —                        | (default, 1G copper module)  |
| 1/3/1 | Garage-8200     | Trunk uplink to 8200     | all VLANs tagged, 10G        |
| 1/3/2 | _(unused)_     | —                          | (default, 10G SFP+)          |

### 8200 feature parity

- `jumbo` (MTU 10200, requires reload — done)
- `inline power allocation dynamic all`
- RSTP: `spanning-tree 802-1w` on VLAN 1, priority 61440
- IGMP/MLD snooping on VLAN 10 (Internal): IGMPv3, MLDv2,
  fast-convergence on both
- `ipv6 mld version 2` (global)

## Observations

- The 7150 had a second SNMP community string that we did not
  configure — it was there pre-existing
  (`$VWlkRGktWg==`). Preserved. Both communities are redacted in
  the committed running.txt as `<REDACTED-SNMP-COMMUNITY-1>` and
  `<REDACTED-SNMP-COMMUNITY-2>`.
- The 7150 had `cli timeout 0` (no idle logout) coming in. The 8200
  had `cli timeout 0` too. Per user direction the 7150's initial
  setup added `console timeout 10` for the serial port, which is
  separate from `cli timeout`. Both are kept.
- Trunk port 1/3/1 came up at 10G immediately when the 8200's
  1/2/1 was already up. The daisy chain segment Garage 8200 →
  Garage 7150 is now live end-to-end.
- Reload for jumbo was clean, ~90s downtime on 1/3/1, came back
  automatically.

## Gotchas (new)

- **VLAN 1 tagging is unnecessary on FastIron** — VLAN 1 is the
  default/untagged VLAN on every port. Tagging it explicitly is
  silently accepted but redundant. We don't tag VLAN 1 on trunks
  (matches the 8200 approach).
- **`vlan 1 tagged ethernet X` would be a no-op on this firmware**,
  not an error — but it's noise in the config. Skipped.

## Still TODO

- Connect the uplink cable between garage-icx-8200 1/2/1 and
  garage-icx-7150 1/3/1 (if not already in place). Once both ends
  are connected and live, end-to-end daisy chain is verified.
- Verify `inline power` allocation works when the doorbells/yard
  devices are actually plugged in.
