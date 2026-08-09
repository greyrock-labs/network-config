# garage-crs309

> **Status:** initial config applied 2026-07-17. vlan-filtering on, mgmt IP on bridge, ports labeled, end-of-spine.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | garage-crs309 |
| FQDN         | garage-crs309.internal.greyrock.io |
| Model        | MikroTik CRS309-1G-8S+IN |
| Hardware rev | r2 |
| Serial #     | HD608ETHR1E |
| Software ID  | IF4R-M3DV |
| RouterOS     | 7.23 (stable), build 2026-05-25 |
| Current firmware | 7.23 (upgraded from 6.48.6 on 2026-07-17) |
| Physical location | garage |
| Role         | backbone switch (Mikrotik spine), end-of-spine |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.16/24 |
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
  - sfp-sfpplus1 → game-room-crs309 (upstream on spine, 10G)
- **Downlinks:**
  - sfp-sfpplus2 → garage-icx-8200 (10G)
  - sfp-sfpplus3 → garage-icx-7150 (10G)
- **Mgmt port:** ether1 (1G copper), VLAN 1 untagged
- **Switching:** CRS3xx hardware switch chip with hardware-offloaded
  bridge.

## Bridge / VLANs

Single bridge `bridge` with `vlan-filtering=yes` and hw-offload.

Used SFP+ ports (carry all 4 VLANs): sfp-sfpplus1, sfp-sfpplus2,
sfp-sfpplus3.

Unused SFP+ ports (VLAN 1 only, no data VLANs): sfp-sfpplus4,
sfp-sfpplus5, sfp-sfpplus6, sfp-sfpplus7, sfp-sfpplus8.

ether1 is mgmt-only: VLAN 1 untagged, no data VLANs.

ether1 is mgmt-only: VLAN 1 untagged, no data VLANs.

## Change history

See `/changes/`. Snapshots in `config/snapshots/`. Current live config
is in `config/running.txt`.

- `2026-07-17-post-initial-config.txt` — `/export` after bridge, VLANs, IP, route, identity rename, NTP client (firmware still 6.48.6)
- `2026-07-17-post-initial-config-system.txt` — system info, routerboard, interface state post-config
- `2026-07-17-post-firmware-upgrade.txt` — `/export` after firmware 6.48.6 → 7.23.
- `2026-07-17-post-rstp-priority-jumbo.txt` — `/export` after STP priority 20480 and jumbo frames (all ports l2mtu=9092 mtu=9000).
- `2026-07-17-post-igmp-mld-snooping.txt` — `/export` after IGMP/MLD snooping enabled, igmp-version=3 mld-version=2 (querier is office-crs309). `running.txt` reflects this state.

## Gaps in the change record

One thing the AI skipped on this box:

1. **Pre-initial-setup baseline is gone and cannot be recovered.**
   The AI failed to ask for the baseline paste before sending the
   bridge config. The user would have to factory-reset the box to
   recreate it, which would wipe the post-config state we just saved.
   Trade-off accepted: post-config is the durable record, pre-state
   is unrecoverable.