# garage-icx-8200

> **Status:** reconfigured for the Mikrotik-backbone topology 2026-07-18, in production. Uplink 1/2/2 → garage-crs309. Port 1/2/1 (former downlink to garage-icx-7150) removed.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | garage-icx-8200 |
| FQDN         | garage-icx-8200.internal.greyrock.io |
| Model        | Ruckus ICX 8200 (ICX8200-C08ZP-POE, Unleashed) |
| Firmware     | 10.0.10g_cd6T253 (RDR10010g_cd6) |
| Software pkg | ICX8200_BASE_L3_SOFT_PACKAGE, license 2X25G |
| Serial #     | FNR4337U0LT |
| Physical location | garage |
| Role         | access (5 APs) |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.17/24 (static, on ve 1 / VLAN 1) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console |
| SSH enabled? | yes |
| DHCP client  | disabled |

## Physical

- **Uplink:** 1/2/2 → garage-crs309 (10G SFP+, full trunk)
- **Downlinks:** none — port 1/2/1 is unused (was the ICX-to-ICX daisy
  link to garage-icx-7150)
- **Stacking:** standalone, 2-port 25G module in slot 2 (not stacked)
- **Power:** single feed, PoE for the 5 APs

## VLANs

| VLAN ID | Name    | Purpose  | Ports                          |
| ------- | ------- | -------- | ------------------------------ |
| 1       | mgmt    | native   | all (untagged)                 |
| 10      | Internal| trusted  | tagged 1/1/1–1/1/5, 1/2/2      |
| 20      | Servers | infra    | tagged 1/2/2                   |
| 4000    | Guest   | guest    | tagged 1/1/1–1/1/5, 1/2/2      |

## Port map

| Port  | Name            | What plugs in            | PoE | BPDU guard | Storm ctrl |
| ----- | --------------- | ------------------------ | --- | ---------- | ---------- |
| 1/1/1 | Garage-AP       | Garage AP                | yes | yes        | 500 pps    |
| 1/1/2 | Garage-Rear-AP  | Garage Rear Driveway AP  | yes | yes        | 500 pps    |
| 1/1/3 | Garage-Side-AP  | Garage Side Yard AP      | yes | yes        | 500 pps    |
| 1/1/4 | Side-Drive-AP   | Garage Side Driveway AP  | yes | yes        | 500 pps    |
| 1/1/5 | Kitchen-AP      | Kitchen AP               | yes | yes        | 500 pps    |
| 1/1/6 | (none)          | unused                   | yes | no         | off        |
| 1/1/7 | (none)          | unused                   | yes | no         | off        |
| 1/1/8 | (none)          | unused                   | yes | no         | off        |
| 1/2/1 | (none)          | unused (former downlink) | no  | no         | off        |
| 1/2/2 | Garage-CRS309   | uplink to garage-crs309  | no  | no         | off        |

## Conventions for this switch

- Unleashed-managed. Don't propose removing from Unleashed.
- Native VLAN 1 is the mgmt VLAN. Don't change.
- 16-char limit on the port-name field.
- APs are BPDU-guarded: if an AP receives a BPDU it err-disables —
  desired behavior, don't remove.
- Multicast is passive on VLAN 10 (both protocols); the IGMP/MLD
  querier is office-crs309. See `topology/multicast-runbook.md`.
- Leaf STP priority 36864 on VLAN 1: this box must never win root.

## Change history

See `/changes/`. Live config in `config/running.txt`. Snapshots in
`config/snapshots/`.

- `2026-07-18-post-topology-change.txt` — `show running-config` after
  reconfiguring for the Mikrotik spine: mgmt IP → 10.1.0.17, port 1/2/1
  removed from VLANs and interface config, 1/2/2 renamed Garage-CRS309
  (full trunk), VLAN 1 STP priority → 36864, DNS added to match fleet.