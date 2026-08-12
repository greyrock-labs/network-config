# 2026-08-12 — VLAN 60 (Cameras), six garage cameras moved onto it

## Why

The garage-icx-7150 hosts six cameras across ports 1/1/1–1/1/6. All
six were on VLAN 10 (Internal) and reachable from every other VLAN,
including guest. That gave every camera:

- A path *out* to vendor clouds, which the trusted LAN had no reason
  to offer them.
- A path *in* from anything on the trusted LAN and the guest network,
  which is the right shape for a desktop and the wrong shape for a
  camera.

VLAN 60 inverts that: cameras can be reached from any other VLAN,
but they can only initiate one thing — NTP to the four servers in
VLAN 20. Everything else outbound is dropped at the forward chain.

## What changed

A new camera segment, VLAN 60 / `10.1.60.0/24`, IPv4-only, built
across the same ten devices as VLAN 50. Full design in
`topology/vlan60-cameras.md`.

**office-rb5009** — `vlan60` interface on the bridge, `10.1.60.1/24`,
bridge + `sfp-sfpplus1` tagged for VLAN 60, `vlan60-cameras` pool
(`.20-.254`), `dhcp-vlan60` (8h leases, ctrld at 10.1.30.20 for DNS,
the four internal NTP servers at 10.1.20.16–19). Three named-camera
reservations:

| Device | MAC | New address | Previously |
| --- | --- | --- | --- |
| garage-camera-todd | 74:3F:C2:E7:EB:78 | 10.1.60.11 | reserved at 10.1.10.66 |
| garage-camera-andy | 74:3F:C2:E7:EB:73 | 10.1.60.12 | reserved at 10.1.10.68 |
| garage-camera-side-yard | 08:CC:81:9A:FD:4F | 10.1.60.10 | dynamic lease (MAC looked up live) |

Only two of the three had a VLAN 10 reservation to remove
(`[find where address=10.1.10.66]` and `.68`), so the static entries
bind cleanly on next DHCP cycle — same pattern as the original
2026-07-31 reservations change. `garage-camera-side-yard` had no prior
reservation or DNS record; its entry is new, not a carry-over.

DNS A records for todd and andy retargeted from the VLAN 10 addresses
(`.66`, `.68`) to the VLAN 60 addresses (`.11`, `.12`); the side-yard
record at `.10` is new. `vlan60` joined both the `LAN` interface list
(required for input-chain DHCP) and the `DNS-FORCE` list (the dst-nat
to ctrld is paired with the explicit DNS-accept firewall rules so
cameras' DNS queries — including the hardcoded-upstream-resolver case
— actually reach 10.1.30.20). `mdns-repeat-ifaces` was expanded to
`vlan10,vlan20,bridge,vlan60` so cameras' ONVIF/Bonjour/RTSP discovery
advertisements reflect to the trusted LAN (and the trusted LAN's
services reflect back); the repeater operates at a separate layer
from the forward-chain firewall, so the strict outbound rules are
unaffected.

**Firewall** — five new rules inserted in the forward chain immediately
after the VLAN 4000 rules and before the defconf accept block, in this
order:

```
add action=accept chain=forward comment="cameras: allow vlan60 DNS to ctrld" dst-address=10.1.30.20 dst-port=53 in-interface=vlan60 protocol=udp
add action=accept chain=forward comment="cameras: allow vlan60 DNS to ctrld" dst-address=10.1.30.20 dst-port=53 in-interface=vlan60 protocol=tcp
add action=accept chain=forward comment="cameras: allow vlan60 to NTP servers" dst-address=10.1.20.16-10.1.20.19 dst-port=123 in-interface=vlan60 protocol=udp
add action=drop chain=forward comment="cameras: drop VLAN 60 to internal" connection-state=new dst-address-list=internal in-interface=vlan60
add action=drop chain=forward comment="cameras: drop VLAN 60 to WAN" connection-state=new in-interface=vlan60 out-interface-list=WAN
```

Order matters: the two DNS accepts must precede the internal drop so
DNS-FORCE-dst-natted traffic to 10.1.30.20 actually reaches ctrld (the
`internal` address-list covers 10.1.30.20 — without the accept rules
the dst-natted traffic would hit the drop and DNS would silently
fail). The NTP accept must precede the drops so its exception is not
blocked by the internal/WAN drops. The "drop to WAN" rule is paired
with the existing defconf masquerade: removing it without removing the
masquerade would silently let VLAN 60 reach the internet.

**Both drop rules carry `connection-state=new`.** Without it, the drops
catch the cameras' *replies* to traffic from other VLANs too — the
very thing the segment is supposed to allow. Walking the chain for an
ICMP reply from a camera (10.1.60.10 → 10.1.10.X): `in-interface=vlan60`
matches, `dst-address-list=internal` covers `10.1.10.X`, the drop fires
*before* defconf accept-established at rule 19 gets a chance, and the
reply never reaches the client. The cameras looked unreachable from any
other VLAN until this was caught at verify time and fixed with
`/ip firewall filter set ... connection-state=new`. With it, only new
outbound connections from vlan60 hit the drops; established replies
(and fasttracked TCP) match defconf accept-established / fasttrack and
pass.

**Spine (three CRS309s)** — VLAN 60 tagged on the used SFP+ ports,
no bridge membership, identical in shape to VLANs 10/20/50/4000:
office and game-room on `sfp-sfpplus1-4`, garage on `sfp-sfpplus1-3`.

**Access (six ICX)** — `vlan 60 name Cameras by port` with the uplink
tagged (`1/2/2` on the 8200s, `1/3/2` on the 7150s). AP ports are not
members.

**garage-icx-7150** — ports `1/1/1` through `1/1/6` moved from VLAN 10
untagged to VLAN 60 untagged. FastIron allows untagged membership in
one VLAN only, so the six ports left VLAN 10 first; VLAN 10 held
`untagged ethe 1/1/1 to 1/1/6` on this switch, and that block now
empties. Port-level settings on 1/1/1–1/1/6 (`stp-bpdu-guard`,
`broadcast limit 500`, `port-name`) are VLAN-independent and
untouched.

## Policy decisions

- **One-way isolation.** The forward chain drops `vlan60 → internal`
  and `vlan60 → WAN`. It does not drop `* → vlan60`. Cameras live
  behind a wall that only faces outward.
- **NTP is the only carve-out.** UDP/123 to 10.1.20.16–19. No NTS
  (TCP/4460) — the cameras do not request it and the NTP servers do
  not offer it. If NTS lands later, add a paired TCP/4460 rule in the
  same position; do not widen the UDP rule.
- **DNS-FORCE included, paired with explicit forward accepts.** The
  dst-nat alone would be a dead end (the dst-natted traffic to
  10.1.30.20 would hit the new internal drop), so the forward chain
  carries explicit `dst-address=10.1.30.20 dst-port=53` accept rules
  for both UDP and TCP. Skipping this pair means cameras' DNS
  silently fails.
- **`mdns-repeat-ifaces` expanded** to `vlan10,vlan20,bridge,vlan60`.
  Cameras advertise ONVIF / RTSP / web-UI discovery via mDNS, and
  Home Assistant on the trusted LAN picks them up that way. The
  repeater operates at a separate layer from the forward-chain
  firewall, so the strict outbound rules do not conflict.
- **`LAN` membership is required.** Same reason as VLAN 50 — the
  input chain ends in `drop all not coming from LAN`, so without it
  DHCP would go unanswered.
- **IPv4 only.** No ULA, no PD carve, no `ipv6 address` on the
  interface, matching VLANs 50 and 4000.
- **Certs are a follow-up.** The existing `garage-camera-*` certs have
  the old VLAN 10 IP in their SANs and need re-issuing with the new
  addresses. Not in scope here — the cameras will still respond on
  HTTPS, the browser will just warn.

## Verified

- `/ip dhcp-server lease print detail where server=dhcp-vlan60` — the
  three reservations present and `status=bound`.
- `/ip dhcp-server lease print where server=dhcp-vlan10` — no
  reservation remains at `10.1.10.66` or `.68`.
- `/ip dns static print where name~"garage-camera"` — three A
  records, each pointing at the new VLAN 60 address.
- `/ip firewall filter print where comment~"cameras"` — five rules
  present, in the right order (DNS UDP/TCP accepts, NTP accept, then
  the two drops).
- `/ip dns mdns-repeat-ifaces print` — `vlan10,vlan20,bridge,vlan60`.
- `/interface bridge vlan print` on all three CRS309s: VLAN 60 row
  with the expected `CURRENT-TAGGED` ports and no `bridge`.
- `show vlan 60` on all six ICX: VLAN 60 named Cameras with the
  expected uplink tagged.
- `show vlan 60` on garage-icx-7150 specifically: `tagged ethe 1/3/2`,
  `untagged ethe 1/1/1 to 1/1/6`.
- `show vlan 10` on garage-icx-7150: no longer lists 1/1/1–1/1/6.
- From a VLAN 10 client: `/ping 10.1.60.11` at `ttl=63` — one router
  hop, confirming it is genuinely off VLAN 10; the DNS name
  `garage-camera-todd.internal.greyrock.io` resolves to it.
- `/ip dhcp-server network print` — the `10.1.60.0/24` row is present
  with gateway `10.1.60.1` and DNS `10.1.30.20`.
- `/ip firewall filter print stats where chain=forward` — the two drop
  rules are matching traffic (internal and WAN both nonzero) and the
  DNS-to-ctrld UDP accept is matching. **The NTP accept rule is still
  at 0 packets**, so the one outbound carve-out this segment grants has
  not yet been exercised by any camera. Confirm a camera actually
  syncs time before treating the NTP path as proven.

## Notes for the next reader

- The "drop VLAN 60 to WAN" rule is the load-bearing one. If the
  masquerade is ever disabled, that rule becomes inert but harmless.
  If the masquerade is ever re-enabled for another reason, the rule
  is what stops VLAN 60 from going with it. Removing both is fine;
  removing only the rule is not.
- The NTP carve-out was entered as `dst-address=10.1.20.16-10.1.20.19`;
  RouterOS normalises that aligned range to `10.1.20.16/30`, which is
  how it prints and how it appears in the capture. Same four addresses.
  If the NTP servers are ever moved off VLAN 20, update the rule; it
  stops working the moment a server's address leaves that /30.
- The six cameras are reachable by name from the trusted LAN at
  `garage-camera-*.internal.greyrock.io`. They are reachable by IP
  from any VLAN. They are reachable by *neither* from the guest VLAN
  (4000) — the existing guest isolation rule dropping 4000 to
  `internal` covers them, and the new "drop vlan60 to internal" rule
  would be redundant even if guest traffic reached the forward chain,
  which it does not (it is dropped earlier).
- Re-issue the three named cameras' TLS certs (their SANs still
  reference the old VLAN 10 IPs) when convenient. Until then, HTTPS
  to the camera's web UI works, the browser just warns.
- These captures are the second since the mgmt-IP renumber, so the
  committed configs continue to match the live per-room addressing.
- RoMON is absent from the RB5009 by choice (`/tool romon print` →
  `enabled: no`), as is any `/ipv6 nd` override. Their absence in this
  capture is intentional, not lost config.
- The back-to-home WireGuard tunnel and `/ip cloud` **are** configured
  and running (`vpn-status: running`, `vpn-port: 61606`) — see
  `changes/2026-07-22-office-rb5009-back-to-home-vpn-and-ntp.md`. They
  were dropped from `running.txt` by the 2026-08-10 VLAN 50 capture and
  are restored here. `/ip cloud print` also exposes a WireGuard
  *private* key for the client config; that field is print-only, never
  emitted by `/export`, and must never be committed. The
  `back-to-home-user` public key is a public key and is committed by
  the same reasoning as the 2026-07-22 change.