# 2026-07-20 — office-rb5009: RA DNS, Quad9 v6, ULA fix, dhcp-dns renew handling

Four separate fixes landed on the live box during 2026-07-20
sessions. Documented together because the only thing that makes
sense to capture in the repo is the post-fix state; the per-fix
timeline is in git history.

## What

- `/ipv6 nd` defconf row: `advertise-dns=yes` → `advertise-dns=self`.
  RDNSS option in the RA now explicitly advertises the router.
- `/ip dns` forwarder list: added `2620:fe::fe` and `2620:fe::9`
  (Quad9 IPv6 anycast) alongside the existing v4 forwarders
  `9.9.9.9` and `149.112.112.112`.
- `/ipv6 address` ULA: subnet id was in the wrong hextet (an extra
  `:0:` in front of the VLAN id put the id in the host portion and
  collapsed all three VLANs to `fdc0:ffee:215:0::/64`). Moved the
  subnet id to the 4th hextet so each VLAN has a distinct /64:
  bridge `fdc0:ffee:215:1::/64`, vlan10 `fdc0:ffee:215:a::/64`,
  vlan20 `fdc0:ffee:215:14::/64`. The old `215:0::` address ages
  out on RA-lifetime expiry.
- `/ip dhcp-server` `lease-script` on `dhcp-vlan1`, `dhcp-vlan10`,
  `dhcp-vlan20` (NOT guest): added a renew guard. The original
  script treated every `leaseBound=1` as a fresh bind and re-ran
  the removal/insert dance on every T1/T2 keepalive. The new
  script checks whether it already owns a `comment=dhcp-dns`
  record for this IP — if so, it does nothing. (No-op on renew.)
- `/ip dns static`: restored the missing
  `address=10.1.20.11 name=kvm-kerfuffle.internal.greyrock.io type=A`
  A record for the KVM - Kerfuffle fixed-reservation lease.

## Why

**RA DNS.** Captured an RA on a client (tcpdump `icmp6 and
ip6[40] == 134`) with `advertise-dns=yes` to see what was actually
on the wire. The RDNSS option (type 25, lifetime 1800s) carried
`fe80::d2ea:11ff:fec7:4fc3` — the router's own link-local, NOT
the forwarder list. So the doc is wrong to claim `yes` leaks
forwarders. The doc-corrected framing is: `yes` advertises the
`/ip dns servers=` forwarder list as RDNSS; `self` advertises
the router's own interface address. With `yes` the capture
showed the link-local; that's because the defconf row on this
build is scoped to the bridge (link-local comes from the
bridge MAC), not because `yes` is `self`. With `self` set, the
behavior is the same on RouterOS 7.23.2 (RDNSS = router's own
address on that interface). We want `self` documented
explicitly so a future change to `yes` doesn't silently leak
the forwarder list to IPv6 clients.

**Quad9 v6.** The RB5009 has a v6 transport now (DHCPv6-PD on
ether1) and the resolver was hitting the v4 forwarders over a
NAT64-ish path. Adding Quad9's v6 anycast saves a few extra hops
for v6 clients and gives the resolver a native v6 upstream.

**ULA fix.** The ULA was supposed to be per-VLAN distinct
(/48 carved into /64s by VLAN id in the 4th hextet) but a typo
put the VLAN id in the 5th hextet, collapsing all three VLANs to
the same /64. Clients autoconf'd into random /64 chunks of
`215:0::/64` regardless of which VLAN they were on, which made
it look like the wrong RA was reaching them.

**dhcp-dns renew handling.** The original script's bound arm
ran the full removal-and-re-add dance on every lease event,
including T1/T2 renews (which come in as `leaseBound=1` but the
lease is already in the table). On a fixed-reservation box that
was the wrong shape — it could clobber hand-managed static DNS
on renew. The new script checks for an existing
`comment=dhcp-dns` record at the same IP and short-circuits
with `:return` if present, treating the event as a renew. Fixed
reservations still skip the inner block via the `dynamic=no`
check, and all remove/insert paths remain scoped to
`comment=dhcp-dns` so the script physically cannot touch a
hand-managed static.

**kvm-kerfuffle restore.** The A record for `kvm-kerfuffle`
disappeared from the live box at some point during 2026-07-20.
The fixed-reservation lease at `10.1.20.11` is still active.
The script cannot have removed it (all paths are scoped to
`comment=dhcp-dns` and the kvm-kerfuffle record had no such
comment). Restored manually. The new renew-handling script
guarantees this cannot happen again on a renew event.

## Evidence

RDNSS option from a single RA, with `advertise-dns=yes`:

```text
rdnss option (25), length 24 (3):  lifetime 1800s, addr: fe80::d2ea:11ff:fec7:4fc3
```

Captured 2026-07-20 15:27 from a client on the office LAN.
The capture did not include Quad9 v4 or v6 in RDNSS — only the
router's own link-local.

## Config deltas

- `/ipv6 nd` `set [find default=yes] advertise-dns=self`
- `/ip dns` `set servers=9.9.9.9,149.112.112.112,2620:fe::fe,2620:fe::9`
- `/ipv6 address` — three `set` calls on the bridge, vlan10,
  vlan20 to move the subnet id to the 4th hextet.
- `/ip dhcp-server` — three `set ... lease-script="..."` calls
  on dhcp-vlan1, dhcp-vlan10, dhcp-vlan20 with the new
  renew-aware script. (Set via WebFig, not CLI, because the
  embedded `"` and `$` need escaping and `$` substitutes at
  set-time.)
- `/ip dns static` `add name=kvm-kerfuffle.internal.greyrock.io
  address=10.1.20.11 type=A`

## Decisions / shortcuts

- **Did not pin RDNSS to the stable GUA.** Per-interface
  `/ipv6 nd` rows could be added to make the RA on a tagged
  sub-interface carry the per-VLAN GUA instead of the
  link-local, but that's a separate change.
- **Did not switch to v6-only upstream.** The v4 forwarders
  already have working v4 paths; v6 is added alongside, not
  instead.
- **The dhcp-dns script is loaded via WebFig, not CLI.** The
  LOAD note at the top of `routers/office-rb5009/config/
  dhcp-dns-register.rsc` documents why — the embedded `"` and
  `$` in the script need escaping and `$` substitutes at CLI
  set-time, mangling the script body. The export you see in
  `running.txt` is the resulting escaped form.

## Repo state

- `routers/office-rb5009/config/running.txt` and
  `routers/office-rb5009/config/snapshots/2026-07-20-16-53-post-ula-fix-dhcp-script-renew-and-kvm-kerfuffle.txt`
  reflect the post-fix state.
- The earlier snapshot
  `routers/office-rb5009/config/snapshots/2026-07-20-15-33-post-ra-dns-self-and-quad9-v6.txt`
  and
  `routers/office-rb5009/config/snapshots/2026-07-20-post-initial-deploy.txt`
  reflect earlier states and are kept for history.
- `routers/office-rb5009/config/dhcp-dns-register.rsc` is the
  in-repo reference copy of the new lease-script.
- `routers/office-rb5009/README.md` ULA mapping table and
  RA-DNS paragraph were updated to match the post-fix state.
