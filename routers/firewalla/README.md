# firewalla

> **Status:** in production as of 2026-08-17 — replaced the MikroTik
> RB5009 as the network gateway. See
> `changes/2026-08-17-firewalla-cutover.md`.

## Identity

| Field        | Value |
| ------------ | ----- |
| Name         | Firewalla |
| Model        | Firewalla Gold Pro |
| Physical location | game room |
| Role         | gateway / L3 routing / firewall / DHCP / DNS / NGFW |

## Management

The Firewalla is managed via the Firewalla mobile app and MSP portal.
There is no CLI config export, no management IP, and no `running.txt`
or snapshots in this directory — the device's config is not capturable
in the same way as the MikroTik switches. The app is the source of
truth for its live state.

## Physical

- **LAN trunk:** Port 1 (10G) → office-crs309 sfp-sfpplus1
  (VLAN 1 untagged + VLANs 10/20/50/60/4000 tagged)
- **WAN:** Port 4 (10G) → Spectrum modem

## Network segments

| VLAN | Name     | Subnet          | Gateway    | Type     |
| ---- | -------- | --------------- | ---------- | -------- |
| 1    | Management | 10.1.0.0/24   | 10.1.0.1   | open     |
| 10   | Internal | 10.1.10.0/24    | 10.1.10.1  | open     |
| 20   | Servers  | 10.1.20.0/24    | 10.1.20.1  | open     |
| 50   | IoT      | 10.1.50.0/24    | 10.1.50.1  | open     |
| 60   | Cameras  | 10.1.60.0/24    | 10.1.60.1  | lockdown |
| 4000 | Guest    | 192.168.23.0/24 | 192.168.23.1 | guest   |

VLAN 30 (Container) was retired — it existed only to host the ctrld
container on the RB5009. The Firewalla provides DNS natively (DoH +
Unbound + Custom DNS Rules), replacing ctrld.

## Features in use

- **NGFW** — IDS/IPS, Active Protect, geo-IP filtering (replaces
  ctrld's DNS-level filtering)
- **DNS** — Custom DNS Rules for infrastructure A records; external-dns
  Firewalla provider for CNAME/TXT records (k8s services)
- **mDNS relay** — enabled on Management, Internal, Servers, Cameras;
  disabled on Guest and IoT
- **IPv6** — dual-stack via Spectrum DHCPv6-PD; GUA per VLAN. No ULA.
- **WireGuard** — TBD (to be configured after cutover)
