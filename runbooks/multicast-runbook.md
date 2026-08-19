# Multicast (IGMP/MLD) runbook

How to see what multicast snooping is doing on this network — CRS309s
(RouterOS) and ICX switches (FastIron). Written for a future reader who
remembers nothing.

## The design in 30 seconds

- All switches snoop IGMP (IPv4) and MLD (IPv6) at **IGMPv3 / MLDv2**.
- **Two queriers, split by VLAN.** A RouterOS bridge querier sends its
  queries untagged into the bridge's PVID VLAN only — it cannot
  originate queries in tagged VLANs (documented RouterOS behavior:
  help.mikrotik.com, "Bridge IGMP/MLD snooping"). So:
  - **VLAN 1 querier: office-crs309** (`multicast-querier=yes` on its
    bridge; queries source 0.0.0.0 / the bridge link-local).
  - **VLAN 10 querier: office-icx-8200** (`multicast active` +
    `multicast6 active` under `vlan 10`; queries source its mgmt IP
    10.1.0.11 / its link-local. A real-IP querier wins any election).
- Every other switch is passive on every VLAN: it snoops, it never
  queries.
- **VLANs 20 and 4000 are unqueried on purpose.** Snooping entries
  there are transient (join → age out → flood), which is the intended
  posture: 20 has no snooping-sensitive workload, and guest 4000 gets
  no querier or switch-CPU presence as a policy decision.
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
`multicast-querier=yes` on office-crs309 only (that flag covers
VLAN 1 only — see the design section).

Who is the elected querier, seen from this box?
```
/interface bridge monitor bridge once
```
Healthy on game-room/garage: `igmp-querier: sfp-sfpplus1 10.1.0.11`
(office-icx-8200, the VLAN-10 querier — the monitor shows one elected
querier and a real-IP querier displaces the 0.0.0.0 VLAN-1 one) and
`mld-querier: sfp-sfpplus1 fe80::...` (office-crs309's bridge
link-local), both via the port facing the office. The port column
tells you where queries enter — follow it switch to switch to find
any rogue querier's physical location.

What groups are being tracked, per VLAN, per port?
```
/interface bridge mdb print
```
This is the ground truth. Healthy: entries on VLANs 1 and 10,
including `ff02::fb` on VLAN 10 (Matter/mDNS). VLAN 20/4000 entries
are transient — they appear on joins and age out unrefreshed because
those VLANs have no querier, by design. Entries age out at
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
Passive = snooping without querying, which is correct for every ICX
except office-icx-8200: that one runs `multicast active` +
`multicast6 active` on VLAN 10 because it is the VLAN-10 querier for
the whole L2 domain.

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
office-icx-8200 show `vlan cfg active` in `show ip multicast vlan 10`
AND `show ipv6 multicast vlan 10` (the MLD half matters most — Matter
lives on `ff02::fb`); do downstream boxes see `igmp-querier` with a
real IP (10.1.0.11) in `monitor bridge once`; is the device's group in
the `mdb print` on the switch it hangs off.

One more signature, learned the hard way: mDNS entries visibly
appearing/disappearing in a browser app while HomeKit works fine is
usually client-side (macOS/iOS sleep-proxy handoffs, dark-wake naps,
and unicast-assist TTL clamping), not the network. Verify multicast
delivery with `ping6 ff02::fb%en0`-style probes before touching switch
config.