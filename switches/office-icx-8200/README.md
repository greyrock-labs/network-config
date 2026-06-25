# office-icx-8200

> **Status:** unconfigured — initial setup pending.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | office-icx-8200 |
| FQDN         | office-icx-8200.internal.greyrock.io |
| Model        | Ruckus ICX 8200 (Unleashed, T-series) |
| Firmware     | (fill in after first capture) |
| Serial #     | (fill in after first capture) |
| Physical location | office |
| Role         | access |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.14/24 (planned) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console |
| SSH enabled? | TBD |
| DHCP client  | TBD |

## Physical

- **Uplinks:**
  - 1/2/1 → office-icx-7150 (downlink, 10G)
  - 1/2/2 → router (uplink, 10G)
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
