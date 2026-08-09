# office-icx-7150

> **Status:** reconfigured for the Mikrotik-backbone topology 2026-07-20, in production. Uplink 1/3/2 → office-crs309.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | office-icx-7150 |
| FQDN         | office-icx-7150.internal.greyrock.io |
| Model        | Ruckus ICX 7150-C12P (Unleashed) |
| Firmware     | 10.0.10g_cd6T213 (SPR10010g_cd6) |
| Software pkg | ICX7150_L3_SOFT_PACKAGE, license 2X10GR |
| Serial #     | FEK3850Q0W1 |
| Physical location | office |
| Role         | access (KVM/infra bridges) |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.12/24 (static, on ve 1 / VLAN 1) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console |
| SSH enabled? | yes |
| DHCP client  | disabled |

## Physical

- **Uplink:** 1/3/2 → office-crs309 (10G SFP+, full trunk)
- **Downlinks:** none — 1/3/1 is unused (was the ICX-to-ICX daisy link
  to office-icx-8200; the box also previously downlinked to
  game-room-icx-8200 on this same port before consolidation)
- **Stacking:** standalone

## VLANs

| VLAN ID | Name    | Purpose  | Ports                                    |
| ------- | ------- | -------- | ----------------------------------------- |
| 1       | mgmt    | native   | all (untagged)                            |
| 10      | Internal| trusted  | tagged 1/3/2; untagged 1/1/8              |
| 20      | Servers | infra    | tagged 1/3/2; untagged 1/1/1–1/1/7        |
| 4000    | Guest   | guest    | tagged 1/3/2                              |

Multicast: passive on VLAN 10 (both protocols); IPv4 flood-unregistered
only on this platform. Querier is office-crs309.

## Port map

| Port  | Name            | What plugs in            | PoE | BPDU guard | Storm ctrl |
| ----- | --------------- | ------------------------ | --- | ---------- | ---------- |
| 1/1/1 | NTP1            | NTP server (VLAN 20 untagged) | yes | yes   | 500 pps    |
| 1/1/2 | NTP2            | NTP server (VLAN 20 untagged) | yes | yes   | 500 pps    |
| 1/1/3 | NTP3            | NTP server (VLAN 20 untagged) | yes | yes   | 500 pps    |
| 1/1/4 | NTP4            | NTP server (VLAN 20 untagged) | yes | yes   | 500 pps    |
| 1/1/5 | KVM-NAS         | NAS KVM (VLAN 20 untagged) | yes | yes     | 500 pps    |
| 1/1/6 | KVM-Kerfuffle   | Kerfuffle KVM (VLAN 20 untagged) | yes | yes | 500 pps   |
| 1/1/7 | KVM-HASS        | HASS KVM (VLAN 20 untagged) | yes | yes    | 500 pps    |
| 1/1/8 | HASS            | Home Assistant host (VLAN 10 untagged) | yes | yes | 500 pps |
| 1/1/9–1/1/12 | (none)    | unused                    | yes | no        | off        |
| 1/2/1–1/2/2 | (none)     | unused (2×1G copper module) | no | no       | off        |
| 1/3/1 | (none)          | unused                    | no  | no         | off        |
| 1/3/2 | Office-CRS309   | uplink to office-crs309   | no  | no         | off        |

## Conventions for this switch

- Unleashed-managed. Don't propose removing from Unleashed.
- Native VLAN 1 is the mgmt VLAN. Don't change.
- Device ports are BPDU-guarded — desired behavior, don't remove.
- Leaf STP priority 36864 on VLAN 1: this box must never win root.

## Change history

See `/changes/`. Live config in `config/running.txt`. Snapshots in
`config/snapshots/`.

- `2026-07-20-post-topology-change.txt` — `show running-config` after
  reconfiguring for the Mikrotik spine: mgmt IP → 10.1.0.12, uplink
  consolidated onto 1/3/2 (renamed Office-CRS309, full trunk), 1/3/1
  unused (previously the ICX-to-ICX upstream to office-icx-8200), VLAN
  1 STP priority → 36864. All eight device ports (NTP1–4,
  KVM-NAS/Kerfuffle/HASS, HASS) unchanged. This is the sixth and final
  ICX cut over to the spine.