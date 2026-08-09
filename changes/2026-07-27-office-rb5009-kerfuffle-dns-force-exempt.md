# 2026-07-27 — office-rb5009: exempt kerfuffle from DNS-FORCE

## What

Two new `/ip firewall nat` rules, added via Winbox ahead of the existing
`DNS-FORCE` dst-nat pair:

```
add chain=dstnat action=accept protocol=udp src-address=10.1.20.10 dst-port=53 comment="kerfuffle: exempt from DNS-FORCE"
add chain=dstnat action=accept protocol=tcp src-address=10.1.20.10 dst-port=53 comment="kerfuffle: exempt from DNS-FORCE"
```

Confirmed placement via `/ip firewall nat print` — both accept rules sit
at indexes 2/3, ahead of the `force internal DNS` dst-nat rules at 4/5.

## Why

`vlan20` (kerfuffle's segment) is a `DNS-FORCE` member, so the existing
dst-nat pair hijacks any port-53 traffic from that VLAN to the ctrld
container (`10.1.30.20`) regardless of what DNS server the client is
actually configured to use. Kerfuffle (10.1.20.10, the k8s node) should
not have its DNS queries silently redirected if it isn't already pointed
at the router's resolver — so it gets a host-specific exemption instead
of pulling all of vlan20 out of DNS-FORCE (which would also un-force
codswallop, the NTP boxes, and everything else on that VLAN).

`chain=dstnat action=accept` is terminating: matching packets skip the
rest of the dstnat chain, so kerfuffle's DNS traffic reaches whatever
resolver it's actually configured to use, untouched.

## Repo state

- `routers/office-rb5009/config/running.txt` updated with the two accept
  rules ahead of the `force internal DNS` pair. No pre-change snapshot
  taken (small toggle); `/ip firewall nat print` output pasted post-change
  confirms the live state matches.
