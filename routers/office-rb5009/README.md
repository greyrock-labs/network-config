# office-rb5009

> **Status:** bench build in progress — will replace the UDM Pro Max as the
> network gateway (WAN, inter-VLAN routing, DHCP, DNS, firewall, IPv6, mDNS).
> Cutover is a single recable (WAN + spine trunk) once validated.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | office-rb5009 |
| FQDN         | office-rb5009.internal.greyrock.io |
| Model        | MikroTik RB5009 |
| RouterOS     | TBD (confirm; upgrade to current before build) |
| Serial #     | TBD |
| Physical location | office |
| Role         | router / L3 gateway / firewall / DHCP / DNS |

## Role (replacing the UDM Pro Max)

Everything the UDM does today moves here:

- **WAN** — ISP handoff + NAT (masquerade)
- **L3 gateways** — one bridge-VLAN interface per VLAN holding the `.1`
  address; router-on-a-stick over the single tagged trunk to office-crs309
- **DHCP** — a server + scope per VLAN, plus reservations
- **DNS** — resolver: forwards upstream, answers `internal.greyrock.io`;
  10.1.0.1 is the address clients use
- **Firewall** — inter-VLAN policy, guest isolation, port-forwards/DNAT
- **IPv6** — dual-stack per VLAN: stable ULA out of `fdc0:ffee:215::/48`
  + GUA from Spectrum DHCPv6-PD /56, RA advertising both.
  Per-VLAN ULA mapping (4th hextet = VLAN id in hex):

  | VLAN | ULA /64                          | Notes |
  |------|----------------------------------|-------|
  | 1    | `fdc0:ffee:215:0:1::/64`         | mgmt  |
  | 10   | `fdc0:ffee:215:0:a::/64`         | internal |
  | 20   | `fdc0:ffee:215:0:14::/64`        | servers (20 hex = 32) |

  VLAN 4000 (guest) gets NO ULA — IPv6 on guest is a deferred task and
  guest is excluded from mDNS reflection already. Mapping: 4th hextet
  = `0`, 5th hextet = VLAN id in hex with zero-padding so multi-digit
  VLANs like 4000 would fit (not used for now). Router is `::1` on each
  segment.

  Mapping: 4th hextet = `0`, 5th hextet = VLAN id in hex (with zero-padding
  so multi-digit VLANs like 4000 don't overflow). Router is `::1` on
  each segment.

  Internal DNS AAAA records point at the ULA addresses so they survive
  a Spectrum GUA prefix change.

  Spectrum delegated prefix lands via PD on the ether1 dhcp-client;
  VLAN interfaces pull addresses from that pool, then RA + DHCPv6
  serve both ULA and GUA to clients.
- **mDNS** — native repeater (`/ip dns mdns-repeat-ifaces`) reflecting
  Bonjour/Matter discovery between VLANs. Active interfaces:
  `vlan10,vlan20,bridge` — VLAN 4000 (guest) deliberately excluded so
  guest clients cannot probe the smart-home fleet.
- **VPN** — TBD (if the UDM terminates one)

## Physical (planned)

- **Spine trunk:** sfp-sfpplus1 (10G) → office-crs309 sfp-sfpplus1
  (VLAN 1 untagged + VLANs 10/20/4000 tagged)
- **WAN:** TBD (ether8 2.5G if internet > 1G, else ether1)
- **Mgmt:** reachable on VLAN 1 / 10.1.0.1 once the bridge is up

## VLAN / subnet map (confirm)

| VLAN | Name     | Subnet          | Gateway (this router) |
| ---- | -------- | --------------- | --------------------- |
| 1    | Management | 10.1.0.0/24   | 10.1.0.1 |
| 10   | Internal | 10.1.10.0/24    | 10.1.10.1 |
| 20   | Servers  | 10.1.20.0/24    | 10.1.20.1 |
| 4000 | Guest    | 192.168.23.0/24 | 192.168.23.1 |

## Change history

See `/changes/`. Live config in `config/running.txt`. Snapshots in
`config/snapshots/`.