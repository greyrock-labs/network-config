# 2026-07-20 — office-rb5009 initial deploy

RB5009 replaces the UDM Pro Max as the network gateway. Live in
production as of today.

## What

Built incrementally on the RouterOS defconf as the base (per user
preference, no from-scratch config). Captured live in
`routers/office-rb5009/config/running.txt` and
`config/snapshots/2026-07-20-post-initial-deploy.txt`.

**VLAN bridge / trunk** (sfp-sfpplus1 → office-crs309, full trunk):
- VLAN 1 native/untagged on all ports
- VLANs 10/20/4000 tagged on bridge + sfp-sfpplus1 only

**Per-VLAN IPv4 gateways:**
- bridge 10.1.0.1/24, vlan10 10.1.10.1/24, vlan20 10.1.20.1/24,
  vlan4000 192.168.23.1/24
- Each VLAN's DHCP server hands out its own gateway as DNS (so DNS
  queries stay link-local and guest can be walled off without a DNS
  firewall hole)

**DHCP servers + 11 fixed reservations** carried over from the UDM
(Bambu A1 Printer, Home Assistant, K8S-Kerfuffle, KVM-Kerfuffle,
NAS-codswallop, KVM-codswallop, KVM-Home Assistant, NTP1-4)

**DNS:**
- Resolver at 10.1.0.1, forwarders 9.9.9.9 / 149.112.112.112
- 11 fixed static records, ~30 dhcp-dns records (IoT), k8s CNAMEs +
  A records for the ingress VIPs (10.1.25.3 internal, 10.1.25.4 external)
- mDNS reflection across vlan10, vlan20, bridge (guest vlan4000
  deliberately excluded)

**Firewall (v4):**
- Defconf chains untouched
- Single guest-isolation drop: `forward drop in-interface=vlan4000
  dst-address-list=internal place-before=0`
- `internal` address-list: 10.1.0.0/16

**IPv6:**
- ULA fdc0:ffee:215::/48: bridge :0:1::, vlan10 :0:a::, vlan20 :0:14::.
  vlan4000 gets no ULA.
- Spectrum DHCPv6-PD /56 on ether1 (prefix-hint=::/56, add-default-route=yes,
  use-peer-dns=no). GUA per-VLAN via `from-pool=spectrum-v6 address=::/64`.
  vlan4000 (guest) omitted — IPv6 on guest deferred.
- RA via the defconf `interface=all` wildcard. No per-interface nd entries
  (no DHCPv6, so M/O bits unused).

**BGP:**
- Instance `greyrock` (AS 64513). Connection to k8s-kerfuffle
  (10.1.20.10, AS 64514), eBGP, learning cluster LoadBalancer routes
  (10.1.25.0/24).

**Mgmt user:** `externaldns` in `write` group (k8s cluster does DDNS).

## Decisions / shortcuts

- **Defer firewall inter-VLAN policy beyond guest**: only guest is
  isolated, internal/mgmt/servers are in the LAN group and open to
  each other.
- **No AAAA + dual-stack reservations**: user said no DHCPv6, so
  static reservations stay v4-only. v6 name resolution will fall
  back to v4 DNS, which is fine in practice.
- **No guest IPv6**: matches mDNS and the guest-isolation posture.

## Still pending

- AAAA + dual-stack reservations (if/when user wants them)
- Guest IPv6 (deferred)
- Strict inter-VLAN policy (deferred; right now mgmt/internal/servers
  are wide open to each other)