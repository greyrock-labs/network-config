# 2026-07-20 — office-icx-7150 cut over: last ICX onto the spine

Sixth and final ICX leaf. This box was structurally different from the
other 7150s: it previously carried **both** SFP+ ports in service —
1/3/1 upstream to office-icx-8200, 1/3/2 downstream to
game-room-icx-8200 (`GameRoom-8200`) — a genuine two-port transit node
in the old daisy chain, not just a spare port.

- Consolidated onto a single uplink: **1/3/2**, renamed
  `Office-CRS309`, full trunk. 1/3/1 dropped entirely (out of VLANs,
  interface block removed).
- Mgmt IP 10.1.0.15 → **10.1.0.12** (renumber pattern: room's 7150 =
  room's 8200 + 1; .15 is now game-room-icx-7150's address, so this
  move was required, not optional).
- Leaf STP priority 8192 → 36864 — this was the lowest priority left
  in the old fleet (second only to whatever was root), now floored
  like every other leaf.
- All eight device ports (NTP1–4, KVM-NAS/Kerfuffle/HASS, HASS)
  untouched.

**All six ICX access switches are now on the Mikrotik spine.** Root
README fleet table and per-switch status all reflect "in production."
Renumber assignments, final: office-crs309 .10, office-icx-8200 .11,
office-icx-7150 .12, game-room-crs309 .13, game-room-icx-8200 .14,
game-room-icx-7150 .15, garage-crs309 .16, garage-icx-8200 .17,
garage-icx-7150 .18.

Remaining work on the topology: office-rb5009 (router) is not yet
deployed — the old router is presumably still doing that job until
it's swapped in.