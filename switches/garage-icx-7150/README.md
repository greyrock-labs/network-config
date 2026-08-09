# garage-icx-7150

> **Status:** reconfigured for the Mikrotik-backbone topology 2026-07-19, in production. Uplink 1/3/2 → garage-crs309.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | garage-icx-7150 |
| FQDN         | garage-icx-7150.internal.greyrock.io |
| Model        | Ruckus ICX 7150-C12P (Unleashed) |
| Firmware     | 10.0.10g_cd6T213 (SPR10010g_cd6) |
| Software pkg | ICX7150_L3_SOFT_PACKAGE, license 2X10GR |
| Serial #     | FEK3849R0HS |
| Physical location | garage |
| Role         | access (cameras / doorbell / desks) |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.18/24 (static, on ve 1 / VLAN 1) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console |
| SSH enabled? | yes |
| DHCP client  | disabled |

## Physical

- **Uplink:** 1/3/2 → garage-crs309 (10G SFP+, full trunk)
- **Downlinks:** none — 1/3/1 is unused
- **Stacking:** standalone
- **Power:** 120W PoE budget, dynamic allocation

## VLANs

| VLAN ID | Name    | Purpose  | Ports                        |
| ------- | ------- | -------- | ---------------------------- |
| 1       | mgmt    | native   | all (untagged)               |
| 10      | Internal| trusted  | tagged 1/3/2; untagged 1/1/1–1/1/6 |
| 20      | Servers | infra    | tagged 1/3/2                 |
| 4000    | Guest   | guest    | tagged 1/3/2                 |

Multicast: passive on VLAN 10 (both protocols); IPv4 flood-unregistered
only on this platform. Querier is office-crs309.

## Port map

| Port  | Name            | What plugs in            | PoE | BPDU guard | Storm ctrl |
| ----- | --------------- | ------------------------ | --- | ---------- | ---------- |
| 1/1/1 | Porch-Doorbell  | doorbell (VLAN 10 untagged) | yes | yes      | 500 pps    |
| 1/1/2 | Garage-Todd     | desk drop (VLAN 10 untagged) | yes | yes     | 500 pps    |
| 1/1/3 | Rear-Driveway   | camera (VLAN 10 untagged) | yes | yes       | 500 pps    |
| 1/1/4 | Rear-Yard       | camera (VLAN 10 untagged) | yes | yes       | 500 pps    |
| 1/1/5 | Side-Yard-Rear  | camera, garage side yard rear (VLAN 10 untagged) | yes | yes | 500 pps |
| 1/1/6 | Garage-Andy     | desk drop (VLAN 10 untagged) | yes | yes     | 500 pps    |
| 1/1/7–1/1/12 | (none)   | unused                   | yes | no         | off        |
| 1/2/1–1/2/2 | (none)    | unused (2×1G copper module) | no | no        | off        |
| 1/3/1 | (none)          | unused                   | no  | no         | off        |
| 1/3/2 | Garage-CRS309   | uplink to garage-crs309  | no  | no         | off        |

## Conventions for this switch

- Unleashed-managed. Don't propose removing from Unleashed.
- Native VLAN 1 is the mgmt VLAN. Don't change.
- Device ports are BPDU-guarded — desired behavior, don't remove.
- Leaf STP priority 36864 on VLAN 1: this box must never win root.
- PoE cycle a device: `no inline power` / `inline power` in its
  interface context; watch with `show poe`.

## Change history

See `/changes/`. Live config in `config/running.txt`. Snapshots in
`config/snapshots/`.

- `2026-07-19-post-topology-change.txt` — `show running-config` after
  reconfiguring for the Mikrotik spine: mgmt IP → 10.1.0.18, uplink
  moved to 1/3/2 (renamed Garage-CRS309, full trunk), 1/3/1 unused,
  VLAN 1 STP priority → 36864, and new port 1/1/5 Side-Yard-Rear
  (camera, VLAN 10 untagged) added same day.