# 2026-07-18 — game-room-icx-8200 and garage-icx-8200 cut over to the spine

Second and third ICX leaves onto the Mikrotik spine, following the
office-icx-8200 pattern from yesterday (see
`changes/2026-07-17-mikrotik-spine-rollout.md`):

- Uplink stays on 1/2/2 as a full trunk, renamed to the room's CRS309
  (GameRoom-CRS309 / Garage-CRS309). Former 1/2/1 ICX-to-ICX downlink
  removed from VLANs and interface config.
- Leaf STP priority 36864 on VLAN 1 (were 12288 / 20480 as mid-chain
  transit switches).
- Mgmt IPs per the renumber: game-room-icx-8200 → 10.1.0.14,
  garage-icx-8200 → 10.1.0.17.
- Multicast stays passive; querier is office-crs309.
- garage-icx-8200 additionally gained the fleet-standard DNS lines its
  old capture lacked.
- Physical note: the reset shuffled chassis between roles — serials in
  the READMEs are re-verified from live `show version` per box.

Remaining: the three ICX 7150s.