# game-room-crs309

> **Status:** initial config applied 2026-07-17. vlan-filtering on, NTP client synchronized, mgmt IP on bridge, all ports labeled.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | game-room-crs309 |
| FQDN         | game-room-crs309.internal.greyrock.io |
| Model        | MikroTik CRS309-1G-8S+IN |
| Hardware rev | r3 |
| Serial #     | HJX0AVXQW5W |
| Software ID  | JEPC-60YK |
| RouterOS     | 7.23 (stable), build 2026-05-25 |
| Current firmware | 7.23 (upgraded from 7.18.2 on 2026-07-17) |
| Physical location | game room |
| Role         | backbone switch (Mikrotik spine) |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.13/24 |
| Mgmt VLAN    | 1 (native, untagged on mgmt port) |
| Default GW   | 10.1.0.1 (office-rb5009) |
| OOB access?  | serial console (9600 8N1) |
| Mgmt access? | MAC-Winbox / SSH on mgmt IP |
| Local users  | admin (default, change after first login) |
| DNS          | 10.1.0.1 |
| NTP client   | enabled; servers time[1-4].internal.greyrock.io (resolved 10.1.20.16-19, iburst) |
| DHCP client  | disabled |

## Physical

- **Uplinks:**
  - sfp-sfpplus1 → office-crs309 (upstream on spine, 10G)
  - sfp-sfpplus2 → garage-crs309 (downstream on spine, 10G)
- **Downlinks:**
  - sfp-sfpplus3 → game-room-icx-8200 (10G)
  - sfp-sfpplus4 → game-room-icx-7150 (10G)
- **Mgmt port:** ether1 (1G copper), VLAN 1 untagged
- **Switching:** CRS3xx hardware switch chip with hardware-offloaded
  bridge.

## Bridge / VLANs

Single bridge `bridge` with `vlan-filtering=yes` and hw-offload.

| VLAN ID | Name    | Purpose  | Carrying ports                  |
| ------- | ------- | -------- | ------------------------------- |
| 1       | mgmt    | native   | all 9 ports untagged            |
| 10      | Internal| trusted  | used SFP+ tagged                |
| 20      | Servers | infra    | used SFP+ tagged                |
| 4000    | Guest   | guest    | used SFP+ tagged                |

Used SFP+ ports (carry all 4 VLANs): sfp-sfpplus1, sfp-sfpplus2,
sfp-sfpplus3, sfp-sfpplus4.

Unused SFP+ ports (VLAN 1 only, no data VLANs): sfp-sfpplus5,
sfp-sfpplus6, sfp-sfpplus7, sfp-sfpplus8.

ether1 is mgmt-only: VLAN 1 untagged, no data VLANs.

## Differences from office-crs309

- Hardware rev **r3** (office is r2). Functionally identical.
- Factory firmware **7.18.2** instead of 6.48.6 — this box shipped with
  RouterOS 7 already on it. No defconf bridge or interface lists
  present.
- Defconf `/export` is just `set enter-setup-on=delete-key` — no
  bridge, no IPs, no defconf lists to remove.
- Required **creating** the bridge (rather than flipping vlan-filtering
  on an existing one like office-crs309). Same end-state, different
  starting path.
- After applying the connectivity block, two stragglers appeared on
  the live config: a host address `10.1.0.13` on sfp-sfpplus1 (no
  prefix; leftover artifact), and a duplicate default route via
  10.1.0.1. Both cleaned up before saving the post-config snapshot.

## Change history

See `/changes/`. Snapshots in `config/snapshots/`. Current live config
is in `config/running.txt`.

- `2026-07-17-pre-initial-setup.txt` — `/export` of minimal factory config
- `2026-07-17-pre-initial-setup-system.txt` — `/system resource`, `/system routerboard`, `/interface print`
- `2026-07-17-post-initial-config.txt` — `/export` after bridge, VLANs, IP, NTP, port comments, hostname rename
- `2026-07-17-post-initial-config-system.txt` — NTP / identity / routerboard state post-config
- `2026-07-17-post-rstp-priority-jumbo.txt` — `/export` after STP priority 12288 and jumbo frames (all ports l2mtu=9092 mtu=9000).
- `2026-07-17-post-igmp-mld-snooping.txt` — `/export` after IGMP/MLD snooping enabled, igmp-version=3 mld-version=2 (querier stays on office-crs309). `running.txt` reflects this state.