# 2026-07-17 — Mikrotik spine rollout, office-icx-8200 cutover

## Why

The ICX-to-ICX daisy chain made every switch a transit hop: one reboot
partitioned everything downstream, and both SFP+ ports on every ICX were
burned on chaining. The new design is a Mikrotik spine — office-rb5009 →
office-crs309 → game-room-crs309 → garage-crs309 over 10G SFP+ — with
each room's ICX pair hanging off its room's CRS309 as leaves, one SFP+
uplink each. See `topology/greyrock-home.md` (rewritten today) and
`topology/crs309-base-config.md` (fleet template).

## What

**All three CRS309s** (bench-configured, captured in their dirs):
- RouterOS firmware → 7.23
- vlan-filtered bridge, hw-offloaded. VLAN 1 untagged on all ports;
  VLANs 10/20/4000 tagged on used ports only — unused ports are VLAN 1
  only, on purpose
- RSTP priorities: office 4096 (root), game-room 12288, garage 20480
- Jumbo frames: all ports l2mtu=9092 mtu=9000
- IGMP/MLD snooping, IGMPv3/MLDv2, querier on office-crs309 only
- NTP against time[1-4].internal.greyrock.io; per-port neighbor comments

**office-icx-8200** (factory reset, reconfigured, now in production):
- Mgmt IP 10.1.0.14 → 10.1.0.11 (fleet renumber in progress; known
  overlaps with old numbering are intentional)
- Downlink 1/2/1 removed; 1/2/2 is the sole uplink → office-crs309
- UH-AP moved 1/1/1 → 1/1/6
- STP priority 4096 → 36864: leaves must never win root. The other five
  ICX need the same treatment when they're reconfigured.
- VLAN 10 multicast active → passive: the querier role moved to
  office-crs309. Multicast validated end-to-end in production
  (see `topology/multicast-runbook.md`, written today).

**Credential scrub:** the June snapshot captures across all six ICX dirs
contained the real admin password hash and SNMP community strings. All
working-tree copies are scrubbed to `<REDACTED-*>` placeholders as of
this change. The June commits containing the real values are already in
pushed history — rotating the ICX admin password and SNMP communities
is the real remediation; a history rewrite is optional on top.