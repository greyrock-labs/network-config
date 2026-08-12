# 2026-08-12 — VLAN 60 tagged on kerfuffle's port (Scrypted)

## Why

Scrypted runs on the k8s cluster and pulls RTSP from the camera fleet
on VLAN 60. It could already *reach* the cameras — `topology/vlan60-cameras.md`
allows inbound from every other VLAN, and kerfuffle sits on VLAN 20 at
`10.1.20.10` — but every stream was routed: garage-icx-7150 → garage-crs309
→ game-room-crs309 → office-crs309 → office-rb5009 → back down to
office-icx-8200. Six-plus continuous camera streams hairpinning through
the RB5009 is bitrate the router has no reason to carry.

Tagging VLAN 60 onto kerfuffle's access port puts the NVR on the camera
segment directly. The pulls become switched L2 and the router drops out
of the video path entirely.

## What changed

**office-icx-8200** — VLAN 60 tagged on `1/1/7` (Kerfuffle). One line:

```
configure terminal
vlan 60
 tagged ethe 1/1/7
end
write memory
```

That is the whole change. VLAN 60 already existed on this switch and was
already tagged on the uplink `1/2/2` (from `changes/2026-08-12-vlan60-cameras.md`),
so no VLAN creation and no spine or router work was needed.

Port `1/1/7` was already a trunk — untagged VLAN 20 (native, kerfuffle's
`10.1.20.10`) plus tagged VLAN 10 — so this adds a third tag to a port
that was already carrying tagged traffic. Port-level settings
(`stp-bpdu-guard`, `broadcast limit 500`, `port-name Kerfuffle`) are
VLAN-independent and untouched.

## Host side — not in this repo, but required

The switch tag alone is inert. Kerfuffle needs a `vlan60` sub-interface
with an address on `10.1.60.0/24` before any traffic uses the new path;
until then Scrypted keeps reaching the cameras via its VLAN 20 default
route and everything still hairpins through the RB5009. Once the
interface is up, the connected route to `10.1.60.0/24` wins over the
default route and the pulls stay on office-icx-8200 — including for the
`garage-camera-*.internal.greyrock.io` names, which already resolve to
`10.1.60.x`.

No RB5009 change was made. There is no `dhcp-vlan60` reservation for
kerfuffle — the address is set on the host. If it is ever moved to DHCP,
note the pool is `.20–.254` and `.10`–`.13` are the named cameras, so a
reservation below the pool (e.g. `10.1.60.2`) is the clean slot.

## Design note — kerfuffle is multi-homed by design

VLAN 60's isolation rules govern what the *cameras* may initiate. They
were never meant to keep the NVR off the segment: Scrypted reaching the
cameras is why the segment exists, and it had that access through the
router before this change. Tagging the port changed the path, not the
permission.

Kerfuffle now sits on VLANs 10, 20 and 60 at once, which is the ordinary
shape for an NVR that serves a camera VLAN and is reached from the LAN.

## Verified

- `show vlan 60` on office-icx-8200 — `tagged ethe 1/1/7 ethe 1/2/2`.
- `show running-config` — captured to
  `config/snapshots/2026-08-12-post-kerfuffle-vlan60.txt` and
  `config/running.txt`. The capture is byte-identical to the previous
  one apart from the VLAN 60 membership line, confirming no drift had
  accumulated on this switch since `2026-08-12-post-vlan60.txt`.

Not yet verified — **the change has not been proven end-to-end.** The
host-side `vlan60` interface and an actual Scrypted pull over the new
path are still outstanding. Confirm a camera stream is switched rather
than routed before treating this as done: from kerfuffle,
`ip route get 10.1.60.11` should return `dev vlan60` and not the VLAN 20
default, and the RB5009's `vlan60` interface counters should stop
climbing with stream traffic.

## Notes for the next reader

- Nothing on the spine or router changed. If VLAN 60 stops working for
  kerfuffle, the switch port is the least likely cause — check the host
  interface first.
- `topology/vlan60-cameras.md` now lists kerfuffle in the ICX membership
  table and in Scope as the segment's one non-camera member. It is a
  consumer of VLAN 60, not a tenant: it takes no DHCP lease from
  `dhcp-vlan60` and has no camera-style isolation applied to it.
