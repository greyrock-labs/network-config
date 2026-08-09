# game-room-icx-8200

> **Status:** unconfigured — initial setup pending.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | game-room-icx-8200 |
| FQDN         | game-room-icx-8200.internal.greyrock.io |
| Model        | Ruckus ICX 8200 (Unleashed, T-series) |
| Firmware     | (fill in after first capture) |
| Serial #     | (fill in after first capture) |
| Physical location | game room |
| Role         | access |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.12/24 (static, on ve 1 / VLAN 1) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console |
| SSH enabled? | TBD |
| Local users  | TBD |
| DHCP client  | disabled |

## Physical

- **Uplinks:**
  - 1/2/1 → game-room-icx-7150 (downlink, 10G)
  - 1/2/2 → office-icx-7150 (uplink, 10G)
- **Stacking:** standalone
- **Power:** TBD

## VLANs

| VLAN ID | Name    | Purpose  | Ports (tagged)         |
| ------- | ------- | -------- | ---------------------- |
| 1       | mgmt    | native   | all                    |
| 10      | Internal| trusted  | TBD                    |
| 20      | Servers | infra    | TBD                    |
| 4000    | Guest   | guest    | TBD                    |

## Change history

See `/changes/`. Snapshots in `config/snapshots/`.
