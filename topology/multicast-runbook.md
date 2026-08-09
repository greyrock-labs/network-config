# Multicast (IGMP/MLD) runbook

How to see what multicast snooping is doing on this network — CRS309s
(RouterOS) and ICX switches (FastIron). Written for a future reader who
remembers nothing.

## The design in 30 seconds

- All switches snoop IGMP (IPv4) and MLD (IPv6) at **IGMPv3 / MLDv2**.
- **office-crs309 is the one querier** for both protocols
  (`multicast-querier=yes` on its bridge). Everything else — the other
  two CRS309s and every ICX — is passive: it snoops, it never queries.
- Unregistered groups **flood** everywhere (CRS: per-port
  `unknown-multicast-flood=yes`; ICX: `ip/ipv6 multicast
  flood-unregistered`). `fast-leave` is off everywhere.
- Matter / HomeKit ride on mDNS: `224.0.0.251` (IPv4, always flooded —
  snooping can't break it) and `ff02::fb` (IPv6 — this one IS snooped,
  and is the usual suspect when Matter devices go unreachable).

## Quirks to remember (they look like bugs, they aren't)

- The RouterOS querier sends IGMP queries **from 0.0.0.0**. Always.
  It has an IP; it doesn't use it. MLD queries source the bridge's
  IPv6 link-local (EUI-64 of the bridge MAC).
- A RouterOS bridge **never lists itself** in the `igmp-querier` /
  `mld-querier` monitor fields — those only show queriers *heard from
  other devices*. On office-crs309 they read `none` when everything is
  healthy. Validate the querier from a downstream switch.
- A 0.0.0.0-sourced querier loses the election to any real-IP querier.
  So when a router (e.g. the RB5009) starts querying, it takes over
  automatically. If a mystery querier appears, that's what happened —
  trace it (below).
- Packet addresses: queries go to `224.0.0.1`, membership reports go to
  `224.0.0.22` (IGMPv3). Reports to 224.0.0.22 are normal chatter, not
  the mDNS repeater.

## CRS309 (RouterOS)

Overall state — snooping on? versions? querier flag?
```
/interface bridge print
```
Look for: `igmp-snooping=yes igmp-version=3 mld-version=2`, and
`multicast-querier=yes` on office-crs309 only.

Who is the elected querier, seen from this box?
```
/interface bridge monitor bridge once
```
Healthy on game-room/garage: `igmp-querier: sfp-sfpplus1 0.0.0.0` and
`mld-querier: sfp-sfpplus1 fe80::...` (both via the port facing the
office). The port column tells you where queries enter — follow it
switch to switch to find any rogue querier's physical location.

What groups are being tracked, per VLAN, per port?
```
/interface bridge mdb print
```
This is the ground truth. Healthy: entries on VLANs 1/10/20/4000,
including `ff02::fb` on VLAN 10 (Matter/mDNS). Entries age out at
`membership-interval` (4m20s) if not refreshed — groups persisting past
that proves the whole query/report loop works. Groups disappearing when
devices go quiet is snooping working, not a fault.

Raw packets, when nothing else explains it:
```
/tool sniffer quick interface=sfp-sfpplus1 ip-protocol=igmp
```
Run through at least one query cycle (2m5s+). VLAN column shows tags.
Queries: `→ 224.0.0.1`. Reports: `→ 224.0.0.22`.

## ICX (FastIron)

FastIron syntax drifts between releases — if a command complains, use
`?` at that point in the command to find the local spelling.

Config side (what's enabled) — in `show running-config`, per VLAN:
`multicast passive` / `multicast6 passive`, `multicast version 3`, and
global `ipv6 multicast version 2`, `ip multicast flood-unregistered`.
Passive = snooping without querying, which is correct for every ICX.

IPv4 snooping state and learned groups:
```
show ip multicast vlan 10
show ip multicast group
```

IPv6 (MLD) equivalents:
```
show ipv6 multicast vlan 10
show ipv6 multicast group
```

Reading the output:

- `0 grp` is NORMAL on a switch with no multicast members attached —
  group entries only come from reports heard on its ports.
- `no rtr port` is NORMAL on this fleet (verified 2026-07-17): the ICX
  never installs a dynamic router port from the CRS queries, but joins
  from attached hosts still propagate upstream by flooding, and the
  upstream CRS MDB tracks them correctly. Since the fleet runs
  IGMPv3/MLDv2 (no report suppression), flooding is harmless. A static
  router port can be pinned under the VLAN (`multicast router-port
  ethernet <uplink>`, use `?` for local syntax) but is not required.
- The real health check: group lifetimes on the uplink keep resetting
  toward 260 (queries arriving), and devices behind the ICX appear in
  the upstream CRS `mdb print` on the ICX-facing port (joins
  propagating).
- `**** Warning! has V2 client` — benign and permanent in a house full
  of IoT: some device only speaks IGMPv2, so the switch runs v2
  compatibility for that one group, per RFC. No action.
- Groups like `ff32:40:fd3x:...` (ff3x::/32, ULA prefix embedded) are
  IPv6 source-specific multicast — the fingerprint of Thread/Matter
  mesh traffic being tracked. Seeing them is a good sign.

If a device is reachable on its mgmt IP but hears no querier and no
VLAN traffic: check which physical CRS port it's patched into. Unused
CRS ports carry VLAN 1 only — mgmt works, everything tagged silently
doesn't.

## Failure signature worth memorizing

Matter/HomeKit devices respond right after you interact with them, then
go "No Response" a few minutes later, then recover when poked: that's a
membership aging out and not being re-queried. Check (in order): does
office-crs309 still have `multicast-querier=yes`; do downstream boxes
see the querier in `monitor bridge once`; is the device's group in the
`mdb print` on the switch it hangs off.