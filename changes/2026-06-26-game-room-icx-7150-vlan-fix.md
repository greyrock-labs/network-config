# 2026-06-26 — game-room-icx-7150 VLAN trunk fix (1/3/2)

## What changed

Added `tagged ethe 1/3/2` to VLANs 10, 20, and 4000 on
game-room-icx-7150. The 1/3/2 port (downlink from game-room-8200)
was not a tagged member of any VLAN, so traffic arriving on that
port from upstream was dropped.

## Why

A doorbell camera on garage-icx-7150 port 1/1/1 became unreachable
after the daisy chain was brought online. The camera's path goes
through every trunk port in the chain: garage-icx-7150 1/3/1 →
garage-icx-8200 1/2/1 → 1/2/2 → game-room-icx-7150 **1/3/2** →
1/3/1 → game-room-icx-8200 1/2/1 → ...

The game-room-icx-7150's 1/3/2 was the broken link. VLAN 10
traffic from upstream arrived at 1/3/2 and was discarded because
1/3/2 wasn't a member of VLAN 10.

After the fix, the camera came back online (pingable from
garage-icx-7150).

## Why this happened

The original staged config and chunks for game-room-icx-7150
included both `tagged ethernet 1/3/1` and `tagged ethernet 1/3/2`
in each VLAN. But the actual running config only had `tagged
ethe 1/3/1` — the second line was silently dropped during the
interactive apply. This went undetected because 1/3/2 was Down
(no cable) at the time, so no traffic was being dropped.

When the cable to game-room-icx-8200 was finally connected later,
the missing tag became a real bug.

## Why it stayed hidden until now

Each switch in the chain was validated as the chain was built.
But the validation looked at the live state, and the live state of
game-room-icx-7150 showed VLAN 10 tagged on `(U1/M3) 1` only.
Neither of us caught the inconsistency because:

1. We didn't compare the running config to the staged config
2. The bug only matters when 1/3/2 has a cable and carries traffic
3. Once traffic started flowing, the symptom (camera unreachable)
   appeared upstream of the actual problem

## Fix

```
configure terminal
vlan 10
tagged ethernet 1/3/2
exit
vlan 20
tagged ethernet 1/3/2
exit
vlan 4000
tagged ethernet 1/3/2
exit
end
write memory
```

## Gotchas (re-confirmed)

- 16-char hard limit on `port-name` field on this firmware
- `no ip telnet server` not needed (telnet off by default)
- `ntp prefer` doesn't exist
- `show ip interface brief` doesn't exist
- `jumbo` requires reload to take effect
- `spanning-tree 802-1w` must be enabled before
  `spanning-tree 802-1w priority`
- VLAN 1 tagging on trunks is unnecessary (VLAN 1 is the default
  untagged VLAN on every port)
- `cli timeout` does not survive a reload on this firmware
- Always validate that trunk port tagging was applied to BOTH
  ports in a 1/3/x or 1/2/x pair when both are intended trunks;
  the firmware accepts partial application without error

## Still TODO

- Check garage-icx-7150 — its 1/3/2 also has the missing-tag bug
  in the committed config, but is currently Down (no cable) so
  doesn't affect anything. If a cable gets connected to 1/3/2 on
  garage-icx-7150 in the future, the same fix needs to be applied.
- All other switches in the chain: confirm VLAN 20 and VLAN 4000
  are also fully tagged on all trunk ports (only VLAN 10 was
  tested end-to-end with the camera issue).
