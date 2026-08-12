# VLAN 60 (Cameras)

A locked-down segment for the garage camera fleet. Built across the same
ten devices as VLAN 50, but the policy is the opposite of IoT: cameras
cannot reach anything other than the four NTP servers, and they are
reached only by clients on other VLANs.

## Purpose

The garage-icx-7150 hosts six cameras today, one per access port:

| Port | Device |
| --- | --- |
| 1/1/1 | courtyard porch doorbell (Reolink) |
| 1/1/2 | garage-camera-todd |
| 1/1/3 | rear driveway |
| 1/1/4 | rear yard |
| 1/1/5 | garage-camera-side-yard |
| 1/1/6 | garage-camera-andy |

All six were on VLAN 10 (Internal) and reachable from everything:
trusted LAN, guest, IoT. That gave every camera more trust than it
needed inbound, and a path outward to vendor clouds that the trusted
LAN had no reason to offer. VLAN 60 closes the outbound path and keeps
the cameras reachable by name from the trusted LAN.

Note that 1/1/2 and 1/1/6 are still named `Garage-Todd` and
`Garage-Andy` on the switch from their previous life as desk drops.
The names are accurate for the cameras now on them.

## Scope

Six tenants today, all on `garage-icx-7150`. The segment is a camera
quarantine, not a generic IoT segment. It is the right place for
*these* cameras because they share a switch and an isolation policy.
Adding a new camera in the office or game room would mean either
extending VLAN 60 to that switch (and accepting that the segment grows
beyond "the garage") or building a parallel segment there — not a
decision to make pre-emptively.

The segment has one non-camera member: `kerfuffle` (k8s node,
office-icx-8200 `1/1/7`), tagged into VLAN 60 on 2026-08-12 so Scrypted
pulls camera RTSP over L2 on the access switch instead of hairpinning
every stream through office-rb5009. It is a *consumer* of the segment,
not a tenant of it — see `changes/2026-08-12-kerfuffle-vlan60.md`.

VLAN 60 is IPv4 only, like VLAN 50. No ULA, no PD carve.

## Addressing

| Field | Value |
| --- | --- |
| VLAN ID | 60 |
| Name | Cameras |
| Subnet | 10.1.60.0/24 |
| Gateway | 10.1.60.1 (office-rb5009, `vlan60`) |
| DHCP pool | 10.1.60.20 – 10.1.60.254 |
| Lease time | 8h |
| DHCP DNS | 10.1.30.20 (ctrld container) — moot, see Policy |
| DHCP NTP | 10.1.20.16, .17, .18, .19 |
| IPv6 | none — IPv4 only |

IPv4 only: no ULA address, no prefix carved from the Spectrum PD, no
IPv6 address on the `vlan60` interface, so there is no prefix to
advertise on the segment.

## Policy

Unlike VLAN 50 (which is "just another routed segment, kept off the
mDNS repeater"), VLAN 60 has explicit outbound rules. The shape is:

- **Inbound from any other VLAN is allowed.** The forward chain does
  not block `* → vlan60`, so any client on VLANs 1/10/20/30/50/4000
  can reach a camera at its 10.1.60.x address. This is the whole
  point of the segment: cameras live behind a one-way wall.
- **Outbound from VLAN 60 is denied by default**, with one carve-out:
  UDP/123 to the four NTP servers at 10.1.20.16–19. Cameras sync time
  and that is all they get to initiate.
- **LAN membership is required**, not cosmetic: the input chain ends
  in `drop all not coming from LAN`, so without it the router will not
  answer DHCP on the segment.
- **`DNS-FORCE` membership is required.** Cameras ship with
  hardcoded upstream resolvers (or pick them up from DHCP option 6
  pointing at the gateway); without the dst-nat, a camera's DNS
  query would either resolve through an external resolver (and the
  forward drop would deny the answer) or fail outright. The dst-nat
  rewrites dst to 10.1.30.20; the firewall explicitly allows that
  traffic to pass (see Firewall rules).
- **Included in `mdns-repeat-ifaces`** alongside VLANs 10 and 20.
  Cameras advertise Bonjour / ONVIF / RTSP / web-UI services via
  mDNS, and reflecting the segment lets those advertisements reach
  the trusted LAN (and vice versa). The repeater handles multicast
  without traversing the forward chain, so this does not conflict
  with the strict outbound firewall rules. VLAN 50 (IoT) and VLAN 4000
  (guest) remain excluded.
- **Guest isolation already covers this segment** in the *opposite*
  direction: the rule dropping VLAN 4000 to `internal` matches
  10.1.0.0/16 which contains 10.1.60.0/24, so guests can never
  initiate traffic to a camera. The new rules make sure the cameras
  cannot initiate to them either.

The masquerade is the defconf one (`chain=srcnat action=masquerade
out-interface-list=WAN`) and is left in place. With the new drop rule
on `out-interface-list=WAN`, nothing from VLAN 60 will reach it.

### Firewall rules — exact shape

Insert immediately after the existing VLAN 4000 rules and before the
defconf accept-established rule. Order matters: the DNS accept must
come first (so DNS-FORCE dst-natted traffic reaches 10.1.30.20), the
NTP accept must precede the drops so its exception is not blocked by
the internal/WAN drops.

```
/ip firewall filter
# (existing — leave in place)
add action=accept chain=forward comment="guest DNS: allow vlan4000 to ctrld container" dst-address=10.1.30.20 dst-port=53 in-interface=vlan4000 protocol=udp
add action=accept chain=forward comment="guest DNS: allow vlan4000 to ctrld container" dst-address=10.1.30.20 dst-port=53 in-interface=vlan4000 protocol=tcp
add action=drop chain=forward comment="guest isolation: drop VLAN 4000 to internal" dst-address-list=internal in-interface=vlan4000

# NEW — VLAN 60 camera isolation
add action=accept chain=forward comment="cameras: allow vlan60 DNS to ctrld" dst-address=10.1.30.20 dst-port=53 in-interface=vlan60 protocol=udp
add action=accept chain=forward comment="cameras: allow vlan60 DNS to ctrld" dst-address=10.1.30.20 dst-port=53 in-interface=vlan60 protocol=tcp
add action=accept chain=forward comment="cameras: allow vlan60 to NTP servers" dst-address=10.1.20.16-10.1.20.19 dst-port=123 in-interface=vlan60 protocol=udp
add action=drop chain=forward comment="cameras: drop VLAN 60 to internal" connection-state=new dst-address-list=internal in-interface=vlan60
add action=drop chain=forward comment="cameras: drop VLAN 60 to WAN" connection-state=new in-interface=vlan60 out-interface-list=WAN

# (defconf rules follow)
```

The DNS accept pair is what makes `DNS-FORCE` membership useful: the
dst-nat rewrites dst to 10.1.30.20, and the forward rule allows that
specific pair through. Without the accept rule, the dst-natted
traffic would hit the "drop VLAN 60 to internal" rule (since
10.1.30.20 is in the `internal` address-list) and DNS would silently
fail.

The NTP exception matches on `dst-port=123 protocol=udp` only — NTP is
UDP/123. NTS would be TCP/4460, and we do not run NTS, so the camera
servers would refuse an NTS request anyway; the rule is left narrow
on purpose. If a future camera needs NTS, add a paired TCP/4460 rule
in the same position.

Return traffic for accepted DNS and NTP requests matches
`defconf: accept established,related,untracked` higher in the chain,
so replies flow back without an explicit rule.

**The two drop rules need `connection-state=new`.** Without it, the
drops catch the cameras' *replies* to traffic from other VLANs too —
the very thing the segment is supposed to allow. Walking the chain
for an ICMP or TCP reply from `vlan60` back to a VLAN 10 client:

- Rule 9 (`drop VLAN 60 to internal`): `in-interface=vlan60` matches,
  `dst-address-list=internal` matches (10.1.10.X is in 10.1.0.0/16).
  Without `connection-state=new`, this matches even on established
  reply traffic — and the drop fires before defconf accept-established
  has a chance at rule 19.
- Defconf accept-established never reached → reply dropped → the
  camera appears unreachable from any other VLAN.

The fix is to scope the drops to new connections only. Established
replies (and fasttracked TCP) match `defconf: accept established,
related,untracked` (and `defconf: fasttrack`) higher in the chain and
pass through. Adding `connection-state=new` to both drops is what makes
"cameras reachable from any other VLAN" actually work.

The `internal` address-list is `10.1.0.0/16`, which covers every other
VLAN (1/10/20/30/50 and the guest subnet 192.168.23.0/24 is *not*
covered — guests and cameras cannot talk in either direction, which
is the desired outcome). The "drop VLAN 60 to WAN" rule is needed
because RouterOS forward chain has no implicit-deny default: without
it, vlan60 → internet would be masqueraded and accepted.

## Reservations and DNS

Four cameras have reservations + DNS records. The remaining two ports
(1/1/3, 1/1/4) have cameras on them but no design-level reservation or
DNS name — they pick dynamic leases from the pool, and earn names if
they're identified later.

| Device | MAC | Address | DNS name |
| --- | --- | --- | --- |
| garage-camera-side-yard | 08:CC:81:9A:FD:4F | 10.1.60.10 | garage-camera-side-yard.internal.greyrock.io |
| garage-camera-todd | 74:3F:C2:E7:EB:78 | 10.1.60.11 | garage-camera-todd.internal.greyrock.io |
| garage-camera-andy | 74:3F:C2:E7:EB:73 | 10.1.60.12 | garage-camera-andy.internal.greyrock.io |
| courtyard-porch-doorbell | EC:71:DB:9B:DE:A9 | 10.1.60.13 | courtyard-porch-doorbell.internal.greyrock.io |

Two of these (todd at `10.1.10.66`, andy at `10.1.10.68`) had existing
`dhcp-vlan10` reservations, removed at apply time so the static entries
bind cleanly on next DHCP cycle — same pattern as the original
2026-07-31 change. `garage-camera-side-yard` and the Reolink had no
prior reservation; their entries are new. The DNS A records follow the
cameras to their new addresses (TTL 1d). No
cert work this time: the existing `garage-camera-*` certs have the
old VLAN 10 IP in their SAN, so they need re-issuing once the new
addresses are live. That is a follow-up; not in scope here.

## Device configuration

### Router — office-rb5009

```
/interface vlan add interface=bridge name=vlan60 vlan-id=60
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 vlan-ids=60
/ip address add address=10.1.60.1/24 interface=vlan60 network=10.1.60.0
/interface list member add interface=vlan60 list=LAN
/interface list member add interface=vlan60 list=DNS-FORCE
/ip pool add name=vlan60-cameras ranges=10.1.60.20-10.1.60.254
/ip dhcp-server add address-pool=vlan60-cameras interface=vlan60 lease-time=8h name=dhcp-vlan60
/ip dhcp-server network add address=10.1.60.0/24 dns-server=10.1.30.20 domain=internal.greyrock.io \
    gateway=10.1.60.1 ntp-server=10.1.20.16,10.1.20.17,10.1.20.18,10.1.20.19
/ip dhcp-server lease add address=10.1.60.11 comment="Garage Camera - Todd" \
    mac-address=74:3F:C2:E7:EB:78 server=dhcp-vlan60
/ip dhcp-server lease add address=10.1.60.12 comment="Garage Camera - Andy" \
    mac-address=74:3F:C2:E7:EB:73 server=dhcp-vlan60
# (the side-yard reservation needs its MAC from the live router — see Apply)
/ip dns static add address=10.1.60.11 name=garage-camera-todd.internal.greyrock.io type=A
/ip dns static add address=10.1.60.12 name=garage-camera-andy.internal.greyrock.io type=A
/ip dns set mdns-repeat-ifaces=vlan10,vlan20,bridge,vlan60
```

The three lines for VLAN 10 that need to be removed (because the
cameras are leaving that segment) — only if no other VLAN 10 tenant
still claims them:

```
/ip dhcp-server lease remove [find where address=10.1.10.66]
/ip dhcp-server lease remove [find where address=10.1.10.68]
/ip dhcp-server lease remove [find where address=10.1.10.133]
/ip dns static remove [find where address=10.1.10.66]
/ip dns static remove [find where address=10.1.10.68]
/ip dns static remove [find where address=10.1.10.133]
```

Use `[find]` rather than explicit IDs so the command survives config
reordering. Add the firewall ruleset from the *Firewall rules* section
above.

`mdns-repeat-ifaces` becomes `vlan10,vlan20,bridge,vlan60` — vlan60 is
added so the camera fleet's Bonjour/ONVIF/RTSP advertisements reach
the trusted LAN (and vice versa).

### Spine — CRS309s

Identical treatment to VLANs 10/20/50/4000: tagged on used SFP+ ports,
no bridge membership.

```
# office-crs309, game-room-crs309 (ports 1-4 used)
/interface bridge vlan add bridge=bridge tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 vlan-ids=60

# garage-crs309 (ports 1-3 used)
/interface bridge vlan add bridge=bridge tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3 vlan-ids=60
```

### Access — ICX

VLAN 60 is tagged on the uplink only. AP ports are not members (no
camera SSID).

| Switch | Uplink | VLAN 60 members |
| --- | --- | --- |
| office-icx-8200 | 1/2/2 | tagged 1/2/2, 1/1/7 (kerfuffle) |
| office-icx-7150 | 1/3/2 | tagged 1/3/2 |
| game-room-icx-8200 | 1/2/2 | tagged 1/2/2 |
| game-room-icx-7150 | 1/3/2 | tagged 1/3/2 |
| garage-icx-8200 | 1/2/2 | tagged 1/2/2 |
| garage-icx-7150 | 1/3/2 | tagged 1/3/2, untagged 1/1/1–1/1/6 (cameras) |

```
configure terminal
vlan 60 name Cameras by port
 tagged ethe <uplink>
end
write memory
```

VLAN 60 carries no `multicast`/`multicast6` configuration, matching
the rest of the fleet. Cameras do not need multicast.

### Device move — garage-icx-7150 ports 1/1/1–1/1/6

FastIron allows a port to be untagged in one VLAN only, so the six
ports leave VLAN 10 before they join VLAN 60. VLAN 10 currently holds
`untagged ethe 1/1/1 to 1/1/6` on this switch; the six ports all
leave that block and join VLAN 60's untagged list.

```
configure terminal
vlan 10
 no untagged ethe 1/1/1 to 1/1/6
vlan 60
 untagged ethe 1/1/1 to 1/1/6
end
write memory
```

Port-level settings on 1/1/1–1/1/6 (`stp-bpdu-guard`, `broadcast
limit 500`, port-name) are VLAN-independent and untouched. The "desk
drop" port-names on 1/1/2 and 1/1/6 are stale and should be renamed
in the same edit (e.g., to `Garage-Todd-Cam` and `Garage-Andy-Cam`),
but that is cosmetic and can be deferred.

## Apply order

Build the segment from the router outward so the trunk is ready
before any camera lands on it. Steps 1–5 add trunk memberships and
interrupt no existing traffic; step 6 is the only one a camera
notices (each drops for a few seconds and returns on 10.1.60.x).

1. **office-crs309 pre-check** — `/interface bridge vlan print`.
   VLANs 10/20/50/4000 must read `tagged=sfp-sfpplus1..4` with no
   `bridge` member. Put them back to that if they differ.
2. **office-rb5009** — interface, address, LAN + DNS-FORCE membership,
   DHCP pool, DHCP server, DHCP network, the three reservations, the
   DNS record updates, the firewall ruleset, and the
   `mdns-repeat-ifaces` update (in that order). Verify
   `/ip dhcp-server lease print` shows the new entries and
   `/ip firewall filter print` shows the new rules *before any
   camera has moved*.
3. **CRS309s** — office, game-room, garage. Tag VLAN 60 on used
   SFP+ ports.
4. **Five ICX — uplink tag only.** office-icx-8200,
   office-icx-7150, game-room-icx-8200, game-room-icx-7150,
   garage-icx-8200.
5. **garage-icx-7150 — uplink tag.**
6. **garage-icx-7150 — port move.** All six cameras drop for a few
   seconds and return on 10.1.60.x.
7. **Certs (follow-up, not blocking)** — re-issue the three named
   cameras' TLS certs with the new VLAN 60 IP in their SANs.

### Per-device commands

#### 1. office-rb5009 — router

```
/interface vlan add interface=bridge name=vlan60 vlan-id=60
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 vlan-ids=60
/ip address add address=10.1.60.1/24 interface=vlan60 network=10.1.60.0
/interface list member add interface=vlan60 list=LAN
/interface list member add interface=vlan60 list=DNS-FORCE
/ip pool add name=vlan60-cameras ranges=10.1.60.20-10.1.60.254
/ip dhcp-server add address-pool=vlan60-cameras interface=vlan60 lease-time=8h name=dhcp-vlan60
/ip dhcp-server network add address=10.1.60.0/24 dns-server=10.1.30.20 domain=internal.greyrock.io \
    gateway=10.1.60.1 ntp-server=10.1.20.16,10.1.20.17,10.1.20.18,10.1.20.19
/ip dhcp-server lease add address=10.1.60.11 comment="Garage Camera - Todd" \
    mac-address=74:3F:C2:E7:EB:78 server=dhcp-vlan60
/ip dhcp-server lease add address=10.1.60.12 comment="Garage Camera - Andy" \
    mac-address=74:3F:C2:E7:EB:73 server=dhcp-vlan60
# (side-yard MAC looked up on the live router — add the line below)
/ip dhcp-server lease add address=10.1.60.10 comment="Garage Camera - Side Yard" \
    mac-address=<MAC_FROM_LIVE> server=dhcp-vlan60
/ip dhcp-server lease remove [find where address=10.1.10.66]
/ip dhcp-server lease remove [find where address=10.1.10.68]
/ip dhcp-server lease remove [find where address=10.1.10.133]
/ip dns static add address=10.1.60.11 name=garage-camera-todd.internal.greyrock.io type=A
/ip dns static add address=10.1.60.12 name=garage-camera-andy.internal.greyrock.io type=A
/ip dns static add address=10.1.60.10 name=garage-camera-side-yard.internal.greyrock.io type=A
/ip dns static remove [find where address=10.1.10.66]
/ip dns static remove [find where address=10.1.10.68]
/ip dns static remove [find where address=10.1.10.133]
/ip dns set mdns-repeat-ifaces=vlan10,vlan20,bridge,vlan60
/ip firewall filter add action=accept chain=forward comment="cameras: allow vlan60 DNS to ctrld" dst-address=10.1.30.20 dst-port=53 in-interface=vlan60 protocol=udp
/ip firewall filter add action=accept chain=forward comment="cameras: allow vlan60 DNS to ctrld" dst-address=10.1.30.20 dst-port=53 in-interface=vlan60 protocol=tcp
/ip firewall filter add action=accept chain=forward comment="cameras: allow vlan60 to NTP servers" dst-address=10.1.20.16-10.1.20.19 dst-port=123 in-interface=vlan60 protocol=udp
/ip firewall filter add action=drop chain=forward comment="cameras: drop VLAN 60 to internal" connection-state=new dst-address-list=internal in-interface=vlan60
/ip firewall filter add action=drop chain=forward comment="cameras: drop VLAN 60 to WAN" connection-state=new in-interface=vlan60 out-interface-list=WAN
```

`connection-state=new` on both drops is **not optional** — see the
Firewall rules section above. Without it the drops swallow the cameras'
replies to inbound traffic and the segment appears unreachable from
every other VLAN.

The five firewall rules must land immediately after the VLAN 4000
rules. `/ip firewall filter print` after each `add` confirms
ordering; if any of them lands below the defconf accept-established
rule, the vlan60 → internal drop will be ineffective for new traffic.

#### 2. office-crs309 — spine (ports 1-4 used)

```
/interface bridge vlan add bridge=bridge tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 vlan-ids=60
```

#### 3. game-room-crs309 — spine (ports 1-4 used)

```
/interface bridge vlan add bridge=bridge tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 vlan-ids=60
```

#### 4. garage-crs309 — spine (ports 1-3 used)

```
/interface bridge vlan add bridge=bridge tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3 vlan-ids=60
```

#### 5. office-icx-8200 — uplink 1/2/2

```
configure terminal
vlan 60 name Cameras by port
 tagged ethe 1/2/2
end
write memory
```

#### 6. office-icx-7150 — uplink 1/3/2

```
configure terminal
vlan 60 name Cameras by port
 tagged ethe 1/3/2
end
write memory
```

#### 7. game-room-icx-8200 — uplink 1/2/2

```
configure terminal
vlan 60 name Cameras by port
 tagged ethe 1/2/2
end
write memory
```

#### 8. game-room-icx-7150 — uplink 1/3/2

```
configure terminal
vlan 60 name Cameras by port
 tagged ethe 1/3/2
end
write memory
```

#### 9. garage-icx-8200 — uplink 1/2/2

```
configure terminal
vlan 60 name Cameras by port
 tagged ethe 1/2/2
end
write memory
```

#### 10. garage-icx-7150 — uplink tag, then port move

```
configure terminal
vlan 60 name Cameras by port
 tagged ethe 1/3/2
vlan 10
 no untagged ethe 1/1/1 to 1/1/6
vlan 60
 untagged ethe 1/1/1 to 1/1/6
end
write memory
```

All six cameras drop for a few seconds during the port move and
return on 10.1.60.x.

## Verification

- `/ip dhcp-server lease print where server=dhcp-vlan60` —
  garage-camera-todd at 10.1.60.11, garage-camera-andy at 10.1.60.12
  bind on next DHCP cycle (status `waiting` until the camera renews).
- `/ping 10.1.60.11` from a VLAN 10 client at `ttl=63` — one router
  hop, confirming it is genuinely off VLAN 10.
- `/ping 10.1.60.11` from the camera itself (via SSH or the camera's
  diagnostic UI) to 10.1.20.16 — NTP reply. Then to anything else in
  10.1.0.0/16 (e.g., 10.1.10.3) — no reply (dropped by forward
  chain). Then to 8.8.8.8 — no reply.
- `/ip firewall filter print where chain=forward` — five `cameras:`
  rules present and contiguous, sitting after the VLAN 4000 block and
  above the defconf rules, in this order: DNS accept UDP, DNS accept
  TCP, NTP accept, drop-to-internal, drop-to-WAN. Both drops must show
  `connection-state=new`. Print the whole chain rather than filtering
  on the comment — position is what matters, and a comment filter
  hides it.
- `/interface bridge vlan print` on each CRS309 — VLAN 60 row present
  with the expected `CURRENT-TAGGED` ports.
- `show vlan 60` on each ICX — expected tagged/untagged members;
  on garage-icx-7150 specifically: `tagged ethe 1/3/2`,
  `untagged ethe 1/1/1 to 1/1/6`.
- `show vlan 10` on garage-icx-7150 — no longer lists 1/1/1–1/1/6.
- `/ip dns print` — `mdns-repeat-ifaces` reads
  `vlan10,vlan20,bridge,vlan60`.
- `/ip dns static print where name~"garage-camera"` — three A records,
  each pointing at the new VLAN 60 address.
- `/ip dhcp-server network print` — the `10.1.60.0/24` row exists with
  gateway `10.1.60.1`. Print unfiltered; a `where address=` filter on
  this table can return empty even when the row is present.

## Notes for the next reader

- The new drop rule `cameras: drop VLAN 60 to WAN` is paired with
  the existing masquerade. Removing it without removing the
  masquerade would silently let VLAN 60 reach the internet.
- The NTP carve-out is a *forward* accept. If the NTP server is ever
  moved off VLAN 20, this rule stops working; update the dst-address
  range rather than dropping the rule.
- Cameras will keep their Hikvision (or vendor) cloud connectivity
  attempts visible in their own logs — the firewall silently drops
  them. That is the point. If a camera is "offline" from the
  vendor's perspective, that is the vendor losing reach to the
  camera, not the camera losing reach to anything else.
- These captures will be the second since the mgmt-IP renumber, so
  the committed configs continue to match the live per-room addressing.