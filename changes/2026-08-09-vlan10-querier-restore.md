# 2026-08-09 — VLAN 10 querier restored (office-icx-8200 active)

## Symptom

After a same-day reset/restore of all nine switches, mDNS entries in
Discovery (iOS/macOS) appeared and disappeared continuously.
Matter/HomeKit devices intermittently unreachable.

## Root cause

VLAN 10 had no IGMP/MLD querier. The design assumed office-crs309's
`multicast-querier=yes` covered all VLANs, but a RouterOS bridge
querier sends queries **untagged into the PVID VLAN only** — it cannot
originate queries in tagged VLANs (help.mikrotik.com, "Bridge IGMP/MLD
snooping"). Two things had masked the gap:

- Until 2026-07-20 the UDM Pro Max was the gateway, and UniFi gateways
  run their own per-VLAN IGMP querier. The 2026-07-17 multicast
  validation happened while it was still alive — it was the invisible
  querier for the tagged VLANs.
- `flood-unregistered` on the whole fleet means aged-out snooping
  entries degrade to flooding, which mostly works. The fleet-wide
  reset cleared all snooping state simultaneously and exposed the
  failure cleanly.

The 2026-07-17 cutover had flipped office-icx-8200 from `multicast
active` (the pre-spine querier, per the 2026-06-26 change) to passive
on the same assumption.

## Change

office-icx-8200, restoring its querier role for VLAN 10 (IGMP + MLD):

```
configure terminal
vlan 10
multicast active
multicast6 active
end
write memory
```

Decisions taken with it:

- office-crs309 keeps `multicast-querier=yes` — it serves VLAN 1,
  where the CRS fleet snoops bridge-wide and the ICX cannot cover it.
- VLAN 20 stays unqueried (transient entries + flooding is fine for
  its workload). If server-side mDNS ever flaps, same fix pattern on
  an ICX carrying VLAN 20.
- Guest VLAN 4000 gets no querier and no switch-CPU membership, as
  policy.
- An experiment adding the bridge as tagged member of VLANs 10/20 on
  office-crs309 was reverted (it does not make the querier VLAN-aware;
  config is back to canonical).

## Verified

- `show ip multicast vlan 10`: `vlan cfg active`, all ports QR, groups
  learned on the uplink with lifetimes refreshing toward 260.
- `show ipv6 multicast vlan 10`: `vlan cfg active`, link-local query
  address, 101 v6 groups across ports.
- game-room-crs309 `monitor bridge once`: `igmp-querier: sfp-sfpplus1
  10.1.0.11` — real-IP election win, arriving from the office side.
- office-crs309 `mdb print`: VID-10 entries including `ff02::fb`.
- End-to-end delivery probes from a wireless VLAN-10 client: `ping6
  ff02::fb%en1` and `ping 224.0.0.251` each answered by 12+ devices.
- HomeKit stable.

## Also ruled out along the way

- RB5009 `mdns-repeat`: A/B-tested off for 11 minutes — no effect on
  residual browse churn. Restored to `vlan10,vlan20,bridge`.
- Unleashed Bonjour Gateway: confirmed disabled.
- IPv6 RA churn from Thread border routers: router set stable across
  flush events.
- Much of the residual browse churn measured on a Mac traced to the
  Mac's own dark-wake sleep cycles (pmset ledger matches mass-removal
  bursts to the millisecond) plus macOS unicast-assist TTL clamping.
  Residual churn is under overnight observation — if Discovery isn't
  rock solid by morning, that investigation continues client-side.

## Repo state

`switches/office-icx-8200/config/running.txt` hand-edited for the two
`vlan 10` lines; fresh captures of all nine switches + router are
pending and will supersede it. Live mgmt IPs on the renumbered fleet
(per-room blocks, e.g. game-room-crs309 .20, garage-crs309 .30) are
ahead of the captures in this repo.
