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
  RA uses `advertise-dns=self` on the defconf `all` row so the
  RDNSS option advertises the RB5009 as the recursive resolver
  (i.e. the router's own interface address, link-local on
  RouterOS 7.23.2). `advertise-dns=yes` would instead leak the
  `/ip dns servers=` forwarder list (9.9.9.9, 149.112.112.112,
  2620:fe::fe, 2620:fe::9) into RDNSS; `self` keeps every IPv6
  client pointed at the RB5009, which then forwards upstream.
  Captured an RA on 2026-07-20 with the prior `yes` setting:
  RDNSS option (type 25) lifetime 1800s, addr = RB5009
  link-local (`fe80::d2ea:11ff:fec7:4fc3`). The capture is from
  the moment before the change; with `self` the behavior is the
  same on RouterOS 7.23.2 (RDNSS = router's own address).
  Per-VLAN ULA mapping (4th hextet = VLAN id in hex; router is ::1
  on each segment):

  | VLAN | ULA /64                          | Notes |
  |------|----------------------------------|-------|
  | 1    | `fdc0:ffee:215:1::/64`           | mgmt  |
  | 10   | `fdc0:ffee:215:a::/64`           | internal |
  | 20   | `fdc0:ffee:215:14::/64`          | servers (20 hex = 32) |

  VLAN 4000 (guest) gets NO ULA — IPv6 on guest is a deferred task
  and guest is excluded from mDNS reflection already. The 4th hextet
  is the subnet id directly (no extra `:0:` in front of it — that
  placed the VLAN id in the host portion and collapsed all three
  ULAs to the same `/64`).

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