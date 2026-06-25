# office-icx-7150

> **Status:** unconfigured — initial setup pending.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | office-icx-7150 |
| FQDN         | office-icx-7150.internal.greyrock.io |
| Model        | Ruckus ICX 7150 (Unleashed, T-series) |
| Firmware     | (fill in after first capture) |
| Serial #     | (fill in after first capture) |
| Physical location | office |
| Role         | access |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.15/24 (planned) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console |
| SSH enabled? | TBD |
| DHCP client  | TBD |

## Physical

- **Uplinks:**
  - 1/3/1 → game-room-icx-8200 (downlink, 10G)
  - 1/3/2 → office-icx-8200 (uplink, 10G) — TBD
- **Stacking:** standalone
- **Power:** TBD

## VLANs

| VLAN ID | Name    | Purpose  | Ports (tagged)         |
| ------- | ------- | -------- | ---------------------- |
| 1       | mgmt    | native   | TBD                    |
| 10      | Internal| trusted  | TBD                    |
| 20      | Servers | infra    | TBD                    |
| 4000    | Guest   | guest    | TBD                    |

## Change history

See `/changes/`. Snapshots in `config/snapshots/`.
