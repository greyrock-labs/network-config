# 2026-06-26 — office-icx-8200 IGMP/MLD querier enable

## What changed

Added `multicast active` and `multicast6 active` to VLAN 10 on the
office-8200 (the STP root and intended querier for the chain).

## Why

The `multicast fast-convergence`, `multicast version 3`,
`multicast6 active`, and `multicast6 fast-convergence` lines that
were already in the running config did NOT actually enable IGMP/MLD
snooping on their own. `show ip multicast vlan 10` returned:

```
global "ip multicast" or vlan "multicast" is not enabled
```

Required additional keyword: `multicast active` (or `multicast
passive` on non-querier switches).

## Applied to office-8200

```
configure terminal
vlan 10
multicast active
multicast6 active
end
write memory
```

## Verified

```
show ip multicast vlan 10
VL10: cfg V3, vlan cfg active, 2 grp, 0 (SG) cache, no rtr port
  My Query address: 10.1.0.14 (ve/loopback/management)

show ipv6 multicast vlan 10
VL10: dft V2, vlan cfg active, 9 grp, 2 (SG) cache
  My Query address: fe80::82f0:cfff:fe1f:ac4a (link-local)
```

Office-8200 is now the IGMP and MLD querier for VLAN 10.

## TODO on other switches

The other 5 switches (office-7150, game-room-8200, game-room-7150,
garage-8200, garage-7150) need `multicast passive` and
`multicast6 passive` on VLAN 10 so they don't try to compete for
querier election. Otherwise the switch with the lowest IP would
win (garage-8200 at 10.1.0.10), which is the opposite of our design.

Apply in order:
1. office-7150 (10.1.0.15)
2. game-room-8200 (10.1.0.12)
3. game-room-7150 (10.1.0.13)
4. garage-8200 (10.1.0.10)
5. garage-7150 (10.1.0.11)

Each one:
```
configure terminal
vlan 10
multicast passive
multicast6 passive
end
write memory
show ip multicast vlan 10
show ipv6 multicast vlan 10
```

Expected `show` output:
```
VL10: cfg V3, vlan cfg passive, X grp
  (this switch is NOT the querier; upstream is)
```

## Gotchas (re-confirmed)

- Input `ipv6 mld version 2` is stored in running-config as
  `ipv6 multicast version 2` — same meaning, different name.
- The per-VLAN `multicast` keyword has sub-options `active` and
  `passive`. `active` makes the switch the querier on that VLAN.
  `passive` makes it listen only.
- Per-VLAN `multicast version 3` configures IGMPv3 on that VLAN.
- Without `multicast active` or `multicast passive` (or global
  `ip multicast`), snooping is NOT active even if the other
  `multicast` lines are present.
