# garage-icx-7150

> **Status:** unconfigured — initial setup pending.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | garage-icx-7150 |
| FQDN         | garage-icx-7150.internal.greyrock.io |
| Model        | Ruckus ICX 7150-C12P (12-port PoE) |
| Firmware     | Unleashed, FastIron (same family as garage-icx-8200) |
| Serial #     | (fill in after first capture) |
| Physical location | garage |
| Role         | access |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | (TBD — 10.1.0.x/24) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console (cable not yet attached) |
| SSH enabled? | TBD |
| Local users  | TBD |
| DHCP client  | TBD |

## Physical

- **Uplinks:** TBD
- **Stacking:** standalone
- **Power:** TBD (PoE+ if C12P variant)

## VLANs

| VLAN ID | Name    | Purpose  | Ports (tagged)         |
| ------- | ------- | -------- | ---------------------- |
| 1       | mgmt    | native   | TBD                    |
| 10      | Internal| trusted  | TBD                    |
| 20      | Servers | infra    | TBD                    |
| 4000    | Guest   | guest    | TBD                    |

## Change history

See `/changes/`. Snapshots in `config/snapshots/`.
