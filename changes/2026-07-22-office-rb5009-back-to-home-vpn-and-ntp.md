# 2026-07-22 — office-rb5009: Back-to-Home WireGuard VPN + NTP client

Additions made live via Winbox and captured in a fresh `/export` on
2026-07-22. Three functional changes; everything else in the diff was
DNS record churn (see "Repo state" on the DNS house rule).

## What

- `/interface wireguard`: new interface `back-to-home-vpn`
  (listen-port 65516, mtu 1420).
- `/ip cloud`: `back-to-home-vpn=enabled`.
- `/ip cloud back-to-home-user`: added `todds-iphone`
  (`allow-lan=yes`, WireGuard public key committed — public key,
  not a secret).
- `/system ntp client`: `enabled=yes`.
- `/system ntp client servers`: `time1..time4.internal.greyrock.io`.
- `/ipv6 dhcp-client` on ether1: `request=prefix` →
  `request=address,prefix`.

## Why

**Back-to-Home VPN.** Deploy MikroTik Back-to-Home WireGuard for
remote access — reach the home network from Todd's iPhone off-site
without standing up a manual WireGuard/road-warrior setup. The
`todds-iphone` peer gets LAN access (`allow-lan=yes`).

**IPv6 DHCP-client `request=address,prefix`.** Changed in support of
the Back-to-Home VPN above — the WAN now requests a routable IPv6
address (IA_NA) on ether1, not just the delegated prefix (IA_PD), so
the Back-to-Home endpoint is reachable over IPv6. Prefix delegation
for the LAN VLANs is unchanged; this only adds the WAN address.

**NTP client.** Point the router's clock at the internal time
servers (`time1..time4.internal.greyrock.io`, the NTP1–4 fixed
reservations on VLAN 20) instead of drifting / relying on defaults.
The router in turn is the DHCP-advertised gateway and resolver, so a
correct clock here matters for the whole site (TLS, logs, DNS).

## Config deltas

- `/interface wireguard add name=back-to-home-vpn listen-port=65516 mtu=1420`
- `/ip cloud set back-to-home-vpn=enabled`
- `/ip cloud back-to-home-user add name=todds-iphone allow-lan=yes public-key="…"`
- `/ipv6 dhcp-client set [find interface=ether1] request=address,prefix`
- `/system ntp client set enabled=yes`
- `/system ntp client servers add address=time1..time4.internal.greyrock.io`

## Repo state

- `routers/office-rb5009/config/running.txt` and
  `routers/office-rb5009/config/snapshots/2026-07-22-post-back-to-home-vpn-and-externaldns.txt`
  reflect the post-change state.
- Both were scrubbed per the new **DNS export house rule** in
  `.claude/CLAUDE.md`: dynamic `/ip dns static` records are stripped
  from saved configs — external-dns A/CNAME records plus their paired
  TXT registry records (created on the rb5009 by external-dns in the
  k8s cluster), and the DHCP-lease-script entries (`comment=dhcp-dns`,
  `ttl=5m`). Only the hand-maintained records backing static
  reservations / infra are kept. This was the first capture to apply
  that rule, so the diff drops a large block of previously-committed
  dynamic entries — that churn is mechanical, not a config change.
