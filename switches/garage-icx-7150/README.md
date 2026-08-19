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
| MAC Address  | C0:C5:20:A0:50:B3 |
| Physical location | garage |
| Role         | access (six cameras) |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.32/24 (static, on ve 1 / VLAN 1) |
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
| 10      | Internal| trusted  | tagged 1/3/2                 |
| 20      | Servers | infra    | tagged 1/3/2                 |
| 50      | IoT     | IoT      | tagged 1/3/2                 |
| 60      | Cameras | garage cameras (isolated) | tagged 1/3/2; untagged 1/1/1–1/1/6 |
| 4000    | Guest   | guest    | tagged 1/3/2                 |

Multicast: passive on VLAN 10 (both protocols); IPv4 flood-unregistered
only on this platform. Querier is office-crs309.

## Port map

| Port  | Name            | What plugs in            | PoE | BPDU guard | Storm ctrl |
| ----- | --------------- | ------------------------ | --- | ---------- | ---------- |
| 1/1/1 | Porch-Doorbell  | courtyard porch doorbell, Reolink `EC:71:DB:9B:DE:A9` → 10.1.60.13 (VLAN 60 untagged) | yes | yes | 500 pps |
| 1/1/2 | Garage-Todd     | garage-camera-todd → 10.1.60.11 (VLAN 60 untagged) | yes | yes | 500 pps |
| 1/1/3 | Rear-Driveway   | camera, dynamic lease (VLAN 60 untagged) | yes | yes | 500 pps |
| 1/1/4 | Rear-Yard       | camera, dynamic lease (VLAN 60 untagged) | yes | yes | 500 pps |
| 1/1/5 | Side-Yard-Rear  | garage-camera-side-yard → 10.1.60.10 (VLAN 60 untagged) | yes | yes | 500 pps |
| 1/1/6 | Garage-Andy     | garage-camera-andy → 10.1.60.12 (VLAN 60 untagged) | yes | yes | 500 pps |
| 1/1/7–1/1/12 | (none)   | unused                   | yes | no         | off        |
| 1/2/1–1/2/2 | (none)    | unused (2×1G copper module) | no | no        | off        |
| 1/3/1 | (none)          | unused                   | no  | no         | off        |
| 1/3/2 | Garage-CRS309   | uplink to garage-crs309  | no  | no         | off        |

Six cameras share this switch, all on VLAN 60 (10.1.60.0/24, isolated —
only inbound from other VLANs allowed). VLAN 60 design and policy in
`topology/vlan60-cameras.md`.

The `Porch-Doorbell` port-name on 1/1/1 predates the Reolink that now
sits there; the name is still accurate. `Garage-Todd` and `Garage-Andy`
on 1/1/2 and 1/1/6 are left over from those ports' previous life as
desk drops and now name the cameras on them.

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
- `2026-08-10-post-vlan50.txt` — capture after adding VLAN 50 (IoT). See `changes/2026-08-10-vlan50-iot.md`.
- `2026-08-12-post-vlan60.txt` — capture after adding VLAN 60 (Cameras)
  and moving ports 1/1/1–1/1/6 from VLAN 10 to VLAN 60. See
  `changes/2026-08-12-vlan60-cameras.md` and `topology/vlan60-cameras.md`.
