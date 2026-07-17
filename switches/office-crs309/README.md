# office-crs309

> **Status:** initial config applied 2026-07-17. vlan-filtering on, NTP client up, defconf lists cleaned. VLAN policy retrofitted to "unused ports = VLAN 1 only".

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | office-crs309 |
| FQDN         | office-crs309.internal.greyrock.io |
| Model        | MikroTik CRS309-1G-8S+IN |
| Hardware rev | r2 |
| Serial #     | HD60848KFNQ |
| Software ID  | 4RMC-F2FX |
| RouterOS     | 7.23 (stable), build 2026-05-25 |
| Current firmware | 7.23 (upgraded from 6.48.6 on 2026-07-17) |
| Physical location | office |
| Role         | backbone switch (Mikrotik spine) |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.10/24 (on bridge) |
| Mgmt VLAN    | 1 (native, untagged on mgmt port) |
| Default GW   | 10.1.0.1 (office-rb5009) |
| OOB access?  | serial console (9600 8N1) |
| Mgmt access? | MAC-Winbox / SSH on mgmt IP |
| Local users  | admin (password changed from default) |
| DNS          | 10.1.0.1 |
| NTP client   | enabled; servers time[1-4].internal.greyrock.io (resolved 10.1.20.16-19, iburst) |
| DHCP client  | disabled |

## Physical

- **Uplinks:**
  - sfp-sfpplus1 → office-rb5009 (spine uplink, 10G)
  - sfp-sfpplus2 → game-room-crs309 (spine downlink, 10G)
- **Downlinks:**
  - sfp-sfpplus3 → office-icx-8200 (10G)
  - sfp-sfpplus4 → office-icx-7150 (10G)
  - sfp-sfpplus8 → unlabeled (currently link-up to something on the
    bench; needs a label and a VLAN policy decision before it can carry
    data VLANs)
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
sfp-sfpplus6, sfp-sfpplus7, sfp-sfpplus8 (the bench device — unlabeled,
so treated as unused until it has a defined purpose).

ether1 is mgmt-only: VLAN 1 untagged, no data VLANs.

## Change history

See `/changes/`. Snapshots in `config/snapshots/`. Current live config
is in `config/running.txt`.

- `2026-07-17-pre-initial-setup.txt` — `/export` of defconf
- `2026-07-17-pre-initial-setup-system.txt` — `/system resource`, `/system routerboard`, `/interface print`
- `2026-07-17-post-firmware-upgrade.txt` — `/export` after firmware 6.48.6 → 7.23
- `2026-07-17-post-firmware-upgrade-system.txt` — system info post-firmware
- `2026-07-17-post-initial-config.txt` — `/export` after vlan-filtering, bridge VLANs, IP move, NTP client, port comments
- `2026-07-17-post-initial-config-system.txt` — bridge / ports / interfaces / IP / routes / DNS / NTP post-config
- `2026-07-17-post-rstp-priority-jumbo.txt` — `/export` after STP priority 4096 (spine root) and jumbo frames (all ports l2mtu=9092 mtu=9000).
- `2026-07-17-post-igmp-mld-snooping-querier.txt` — `/export` after IGMP/MLD snooping enabled with multicast-querier=yes (this box is the domain querier), igmp-version=3 mld-version=2. `running.txt` reflects this state.
- `2026-07-17-post-retrofit-vlan-rule.txt` — `/export` after VLAN policy retrofit (unused ports out of VLANs 10/20/4000).
- `2026-07-17-post-port8-removal.txt` — `/export` after sfp-sfpplus8 removed from data VLANs (treated as unlabeled/unknown). `running.txt` reflects this state.