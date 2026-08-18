# 2026-08-17 — Firewalla Gold Pro replaces RB5009 as gateway

## Why

The MikroTik RB5009 was the network gateway since 2026-07-20. It
provided routing, firewall, DHCP, DNS (via ctrld container), and
WireGuard VPN. The Firewalla Gold Pro replaces it because:

- **NGFW features** — IDS/IPS, Active Protect, geo-IP filtering, ad/
  malware blocking. The RB5009 is a traditional stateful firewall with
  no threat inspection. ctrld provided DNS-level filtering ($60/yr)
  but that's a subset of what the Firewalla does natively.
- **Simpler management** — app-based, no CLI config to maintain.
- **Cost** — returning the RB5009 (~$250) and dropping ctrld ($60/yr)
  offsets the Firewalla's cost.

The RB5009's BGP-to-k8s feature is replaced by L2 networking — the
cluster is single-node, so no routing protocol is needed.

## What changed

**Gateway:** Firewalla Gold Pro in the game room.
- Port 1 (10G) → office-crs309 sfp-sfpplus1 (LAN trunk)
- Port 4 (10G) → Spectrum modem (WAN)

**Network segments (6, down from 7):**

| VLAN | Name | Subnet | Type |
|------|------|--------|------|
| 1 | Management | 10.1.0.0/24 | open |
| 10 | Internal | 10.1.10.0/24 | open |
| 20 | Servers | 10.1.20.0/24 | open |
| 50 | IoT | 10.1.50.0/24 | open |
| 60 | Cameras | 10.1.60.0/24 | lockdown |
| 4000 | Guest | 192.168.23.0/24 | guest |

VLAN 30 (Container) was retired — it existed only to host the ctrld
container on the RB5009. The Firewalla provides DNS natively (DoH +
Unbound + Custom DNS Rules).

**Firewall rules:**
- Guest: auto-created by "guest" network type (block to local, block
  from internet).
- Cameras: auto-created by "lockdown" network type (block to local,
  block to internet, allow inbound from internal) plus a manual NTP
  carve-out rule (allow Cameras → 10.1.20.16/30:123 UDP).

**DNS:**
- Custom DNS Rules for infrastructure A records (switches, APs, cameras,
  k8s VIP, NTP, services).
- DHCP lease registration is native (dnsmasq).
- CNAME/TXT records for k8s services will be managed by external-dns
  via its Firewalla provider (not yet configured).
- `kerfuffle.internal.greyrock.io` is a hard-coded override (dnsmasq
  gets confused by multiple services on the k8s node).

**mDNS relay:** enabled on Management, Internal, Servers, Cameras;
disabled on Guest and IoT.

**IPv6:** dual-stack via Spectrum DHCPv6-PD, GUA per VLAN. No ULA
(the RB5009's `fdc0:ffee:215::/48` ULA scheme is retired).

**WireGuard:** TBD — to be configured after cutover.

**DHCP reservations:** to be added after cutover once devices appear
in the app. The 16 reservations from the RB5009:
- Home Assistant (10.1.10.3), Bambu A1 (10.1.10.74)
- K8S Kerfuffle (10.1.20.10), KVM Kerfuffle (10.1.20.11), NAS
  codswallop (10.1.20.12), KVM codswallop (10.1.20.13), KVM Home
  Assistant (10.1.20.14), NTP1-4 (10.1.20.16-19)
- SolarEdge (10.1.50.10)
- Garage cameras (10.1.60.10-13)

## What was removed from the repo

- `routers/office-rb5009/` — deleted entirely (README, running.txt,
  snapshots, ctrld.toml, bgp-k8s.rsc, dhcp-dns-register.rsc)
- All references to `office-rb5009` / `RB5009` in topology, switch
  READMEs, runbooks, and the main README updated to `firewalla`.
- Historical `changes/*.md` docs left intact — they record what
  happened, not what is.

## What was added

- `routers/firewalla/README.md` — new router README documenting the
  Firewalla's segments, features, and physical connections. No
  running.txt or snapshots (the Firewalla is app-managed, not
  CLI-exportable).

## Verified

- All network segments created and active in the app.
- Guest isolation rules auto-created (block to local, block from
  internet).
- Camera lockdown rules auto-created + NTP carve-out added.
- mDNS relay enabled on the correct segments.
- Custom DNS rules added for infrastructure + services.
- IPv6 enabled on WAN and all LAN segments.
- Internet connectivity confirmed post-cutover.

## Notes for the next reader

- The Firewalla has no CLI config export. Its config lives in the app
  and MSP portal — there is no `running.txt` to capture. This is a
  deliberate trade-off of the platform.
- VLAN 30 is gone. If anything still references 10.1.30.x (ctrld),
  it's stale — update it to use the Firewalla's built-in DNS.
- The RB5009's ULA scheme (`fdc0:ffee:215::/48`) is retired. Internal
  IPv6 DNS records that pointed at ULA addresses will need updating
  if they were used.
- WireGuard VPN is not yet configured on the Firewalla.
- DHCP reservations are pending — add them in the app once devices
  appear on the network.
