# CRS309 base config template

Source of truth: each box's `switches/<hostname>/config/running.txt`
(all three captured live 2026-07-17, post multicast rollout).

Every CRS309 in the fleet shares the same base config. Only the
per-switch fields below differ.

## Per-switch fields

| Field              | office-crs309                | game-room-crs309             | garage-crs309                |
| ------------------ | ---------------------------- | ---------------------------- | ---------------------------- |
| Hostname           | `office-crs309`              | `game-room-crs309`           | `garage-crs309`              |
| Mgmt IP            | `10.1.0.10/24`               | `10.1.0.13/24`               | `10.1.0.16/24`               |
| STP priority       | 4096 (spine root)            | 12288                        | 20480                        |
| Multicast querier  | yes (IGMP + MLD)             | no                           | no                           |
| Used SFP+ ports    | 1, 2, 3, 4                   | 1, 2, 3, 4                   | 1, 2, 3                      |
| Unused SFP+ ports  | 5, 6, 7, 8                   | 5, 6, 7, 8                   | 4, 5, 6, 7, 8                |
| Port 1 neighbor    | `office-rb5009` (upstream)   | `office-crs309` (upstream)   | `game-room-crs309` (upstream)|
| Port 2 neighbor    | `game-room-crs309` (downstream)| `garage-crs309` (downstream)| `garage-icx-8200`            |
| Port 3 neighbor    | `office-icx-8200`            | `game-room-icx-8200`         | `garage-icx-7150`            |
| Port 4 neighbor    | `office-icx-7150`            | `game-room-icx-7150`         | unused                       |

## Fleet-wide standards (identical on all three)

- **RSTP** — RouterOS bridge default (`protocol-mode=rstp`), no command
  needed. Priorities set in DECIMAL (`priority=4096`); `print` displays
  hex. Root proximity follows spine order from the router.
- **Jumbo frames** — set on the ethernet ports, NOT the bridge (the
  bridge mtu=auto follows the lowest member port):
  `/interface ethernet set [find] l2mtu=9092 mtu=9000`
- **IGMP/MLD snooping** — one knob covers both protocols:
  `igmp-snooping=yes igmp-version=3 mld-version=2` (versions match the
  ICX fleet: IGMPv3 / MLDv2). Querier only on office-crs309
  (`multicast-querier=yes`); the RouterOS IGMP querier always sources
  0.0.0.0 (loses election to any real-IP querier — intentional handoff
  when the RB5009 eventually queries). MLD querier sources the bridge's
  IPv6 link-local.
- **Unregistered multicast floods** — per-port
  `unknown-multicast-flood=yes` (default, untouched) matches the ICX
  `flood-unregistered` posture. `fast-leave` stays off everywhere (all
  active ports are aggregation paths).
- **VLAN policy** — VLAN 1 untagged on all 9 ports; VLANs 10/20/4000
  tagged on **used** SFP+ ports only. Update the port `comment` and
  VLAN membership together when a port changes role.

## Base config (RouterOS 7, /export format)

```
/interface bridge
add name=bridge priority=<per-switch> igmp-snooping=yes igmp-version=3 mld-version=2 vlan-filtering=yes
    (office only: multicast-querier=yes)
/interface ethernet
set [ find default-name=ether1 ] l2mtu=9092 mtu=9000
set [ find default-name=sfp-sfpplus1 ] l2mtu=9092 mtu=9000
... (all 8 SFP+ ports identical)
/interface bridge port
add bridge=bridge comment=mgmt interface=ether1
add bridge=bridge comment="to <port 1 neighbor> (spine uplink)" interface=sfp-sfpplus1
add bridge=bridge comment="to <port 2 neighbor>" interface=sfp-sfpplus2
add bridge=bridge comment="to <port 3 neighbor>" interface=sfp-sfpplus3
add bridge=bridge comment="to <port 4 neighbor>" interface=sfp-sfpplus4
add bridge=bridge comment=unused interface=sfp-sfpplus5..8
/interface bridge vlan
add bridge=bridge untagged=<all 9 ports> vlan-ids=1
add bridge=bridge tagged=<used SFP+ only> vlan-ids=10
add bridge=bridge tagged=<used SFP+ only> vlan-ids=20
add bridge=bridge tagged=<used SFP+ only> vlan-ids=4000
/ip address
add address=<mgmt IP>/24 interface=bridge network=10.1.0.0
/ip dns
set servers=10.1.0.1
/ip route
add dst-address=0.0.0.0/0 gateway=10.1.0.1
/system clock
set time-zone-name=America/New_York
/system identity
set name=<hostname>
/system ntp client
set enabled=yes
/system ntp client servers
add address=time1.internal.greyrock.io
add address=time2.internal.greyrock.io
add address=time3.internal.greyrock.io
add address=time4.internal.greyrock.io
```

## Apply-order (conditional on the box's factory state)

1. **Firmware** — `/system routerboard upgrade`, reboot, verify
   `current-firmware` matches the RouterOS version. Do this FIRST.
2. **Bridge** — old factory images ship a defconf bridge: flip
   vlan-filtering in place. New images ship bare: create the bridge.
   Never remove existing ports to change bridge settings.
3. **Bridge ports** — all 9 ports, pvid=1.
4. **Bridge VLANs** — per the VLAN policy above.
5. **Connectivity** — IP on the bridge, default route, DNS. (Remove any
   defconf IP from sfp-sfpplus1 first if present.)
6. **NTP** — enable + four time servers.
7. **Fleet standards** — STP priority, jumbo MTU, snooping/versions
   (+ querier on office only).
8. **Port comments** — label every port.
9. **Capture** — `/export` → `running.txt` + dated snapshot + README
   change-history entry. Every change, every time.

## Validation commands

- `/interface bridge print` — priority, actual-mtu 9000, snooping,
  versions, querier flag
- `/interface bridge monitor bridge once` — STP root + elected
  querier as seen from this box (a bridge never self-reports as
  querier; validate from a downstream box)
- `/interface bridge port print detail` — HW-offload flag, per-port
  comments, flood settings
- `/interface bridge mdb print` — learned multicast groups per VLAN;
  entries persisting past membership-interval (4m20s) proves the
  query/report refresh loop works
- `/tool sniffer quick interface=<port> ip-protocol=igmp` — raw
  query/report traffic (queries → 224.0.0.1, reports → 224.0.0.22)