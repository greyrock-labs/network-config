# office-rb5009

> **Status:** in production as of 2026-07-20 — replaced the UDM Pro Max as
> the network gateway (WAN, inter-VLAN routing, DHCP, DNS, firewall, IPv6,
> mDNS). See `changes/2026-07-20-office-rb5009-initial-deploy.md` and
> `changes/2026-07-20-office-rb5009-ra-dns-and-quad9-v6.md`.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | office-rb5009 |
| FQDN         | office-rb5009.internal.greyrock.io |
| Model        | MikroTik RB5009 |
| RouterOS     | 7.23.3 |
| Serial #     | HMM0BDDPJAM |
| MAC Address  | D0:EA:11:C7:4F:C3 |
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
- **IPv6** — dual-stack on VLANs 1/10/20/30: stable ULA out of
  `fdc0:ffee:215::/48` plus GUA from the Spectrum DHCPv6-PD /56.
  Per-VLAN ULA mapping (4th hextet = VLAN id in hex; router is ::1
  on each segment):

  | VLAN | ULA /64                          | Notes |
  |------|----------------------------------|-------|
  | 1    | `fdc0:ffee:215:1::/64`           | mgmt  |
  | 10   | `fdc0:ffee:215:a::/64`           | internal |
  | 20   | `fdc0:ffee:215:14::/64`          | servers (20 hex = 32) |
  | 30   | `fdc0:ffee:215:1e::/64`          | container (30 hex = 1e) |

  The 4th hextet is the subnet id directly (no extra `:0:` in front of
  it — that places the VLAN id in the host portion and collapses the
  ULAs onto the same `/64`).

  VLANs 4000 (guest) and 50 (IoT) are IPv4-only: no ULA, no PD carve.

  There is no IPv6 DNS server on this network, so the router carries no
  `/ipv6 nd` override — ND runs at RouterOS defaults.

  Internal DNS AAAA records point at the ULA addresses so they survive
  a Spectrum GUA prefix change.

  Spectrum delegated prefix lands via PD on the ether1 dhcp-client;
  VLAN interfaces pull addresses from that pool.
- **mDNS** — native repeater (`/ip dns mdns-repeat-ifaces`) reflecting
  Bonjour/Matter discovery between VLANs. Active interfaces:
  `vlan10,vlan20,bridge`. VLAN 4000 (guest) is excluded so guest clients
  cannot probe the smart-home fleet; VLAN 50 (IoT) is excluded to keep
  misbehaving devices' mDNS off the trusted LAN — see
  `topology/vlan50-iot.md`.
- **VPN** — none configured. A back-to-home WireGuard tunnel and the
  matching `/ip cloud` config are a planned task.

## Physical

- **Spine trunk:** sfp-sfpplus1 (10G) → office-crs309 sfp-sfpplus1
  (VLAN 1 untagged + VLANs 10/20/50/4000 tagged)
- **WAN:** ether1 — this is the **2.5G** port on the RB5009 (ether2–8 are 1G,
  sfp-sfpplus1 is 10G). Standalone routed L3 interface, **not** on the bridge.
  Links at 2.5Gbps full-duplex to the Spectrum modem.
- **Mgmt:** reachable on VLAN 1 / 10.1.0.1

## VLAN / subnet map

| VLAN | Name     | Subnet          | Gateway (this router) |
| ---- | -------- | --------------- | --------------------- |
| 1    | Management | 10.1.0.0/24   | 10.1.0.1 |
| 10   | Internal | 10.1.10.0/24    | 10.1.10.1 |
| 20   | Servers  | 10.1.20.0/24    | 10.1.20.1 |
| 30   | Container | 10.1.30.0/24   | 10.1.30.1 (ctrld resolver at 10.1.30.20) |
| 50   | IoT      | 10.1.50.0/24    | 10.1.50.1 |
| 4000 | Guest    | 192.168.23.0/24 | 192.168.23.1 |

## DNS export rule

When saving this router's config (`running.txt` and any snapshot), strip
the dynamic `/ip dns static` records and keep only hand-maintained infra
records:

- **Strip** external-dns A/CNAME records and their paired TXT registry
  records (the k8s cluster's `k8s.main.*` entries, `ttl=1h`).
- **Strip** DHCP-lease-script entries — those carry
  `comment=dhcp-dns` and `ttl=5m`.
- **Keep** records backing static DHCP reservations and infrastructure
  (switch/AP/router names, NTP, k8s VIP, cameras, `solaredge`).

The saved `/ip dns static` section starts with a comment block restating
this so the next reader of the capture knows records were removed.

## Change history

See `/changes/`. Live config in `config/running.txt`. Snapshots in
`config/snapshots/`.

- `2026-08-10-post-vlan50.txt` — `/export` after adding VLAN 50 (IoT):
  `vlan50` interface, 10.1.50.1/24, `dhcp-vlan50` + `vlan50-iot` pool,
  SolarEdge reservation at 10.1.50.10, `solaredge` DNS record, `LAN` +
  `DNS-FORCE` membership. Excluded from `mdns-repeat-ifaces`.
  See `changes/2026-08-10-vlan50-iot.md`.