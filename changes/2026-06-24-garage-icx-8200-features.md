# 2026-06-24 — garage-icx-8200 features: jumbo, RSTP, IGMP/MLD, dynamic PoE

## What changed

Applied the four "TO DO" features from the initial-setup note.

### 1. Jumbo frames (global)

- `jumbo` — enables 9216-byte MTU on all ports.
- **REQUIRES A RELOAD** to take effect. The command is in running
  config and saved to flash, but the actual MTU change happens at
  boot. Plan a maintenance window to bounce the switch.

### 2. RSTP (Rapid Spanning Tree)

- `spanning-tree 802-1w` on VLAN 1 — enables RSTP on the management
  VLAN (the only one where STP matters on this access switch).
- `spanning-tree 802-1w priority 61440` — sets the bridge priority to
  the high end of the range. The root bridge for VLAN 1 should be
  the office 8200 (first switch in the daisy chain, near the
  router). Setting this switch to 61440 makes it definitely not the
  root.
- Gotcha: RSTP must be enabled (`spanning-tree 802-1w`) before the
  priority command will accept. The error if you skip the enable is
  "IEEE 802-1w is not enabled".

### 3. IGMP/MLD snooping (VLAN 10 only)

- `ipv6 mld version 2` (global) — MLD v2 for IPv6 multicast.
- On VLAN 10 (Internal, the only VLAN with multicast-aware devices):
  - `multicast fast-convergence`
  - `multicast version 3` — IGMPv3 for IPv4
  - `multicast6 active` — enable MLD snooping
  - `multicast6 fast-convergence`
- Verified with `show ip multicast` — VLAN 10 has the config,
  global IGMP/MLD is up.
- Not applied to VLANs 1, 20, 4000 — per user direction, only VLAN
  10.

### 4. Dynamic PoE allocation (global)

- `inline power allocation dynamic all` — switch tracks actual PD
  power draw and only allocates what's needed per port, rather than
  reserving the class-max for every port. With 240W total budget
  and 5 PoE APs, this matters.
- Verified: command accepted, no error.

## Why each decision

- **RSTP only on VLAN 1**: STP is only relevant for L2 loops. VLAN
  1 is the only VLAN where this switch is in a true L2 path with
  potential for loops (the trunk to game room 8200, which is in the
  daisy chain). Per-VLAN STP is cleaner than a single instance.
- **RSTP over STP**: faster convergence, and the firmware supports
  it. No reason to use classic STP.
- **Priority 61440 (high)**: this switch is the second-to-last hop
  in the chain. It should not be the STP root. The root is near the
  router (office 8200). High priority = "I am definitely not root."
- **IGMP/MLD only on VLAN 10**: that's where end-user devices live
  (the APs tag their internal SSID traffic on VLAN 10). Servers,
  guest, and mgmt VLANs don't have multicast clients in this design.
- **Dynamic PoE**: AP power draw varies. Static allocation would
  reserve ~30W per port even if APs only use 8W. Dynamic saves
  budget for actually-plugged-in devices.

## Reload plan

- `jumbo` requires a reboot. Reload will briefly drop 1/2/2 (uplink
  to game room 8200), which is one link in the daisy chain.
- Schedule: pick a low-traffic window. Reload typically takes
  60-90 seconds on ICX 8200s.
- The other three features take effect immediately and don't need
  a reload.
- After reload, verify with `show jumbo` (or check MTU on a port)
  and confirm the uplink comes back UP.

## Gotchas (additions to the original list)

- **`show ip igmp snooping vlan X`** does NOT exist on this
  firmware. Use `show ip multicast` (returns a summary) or
  `show ip multicast vlan X` for per-VLAN detail.
- **`spanning-tree 802-1w` must be enabled before
  `spanning-tree 802-1w priority`** — separate commands, not one.
- **Jumbo command accepted without args; no size parameter on this
  firmware.** Default is 9216.
