# garage-icx-8200

> **Status:** initial setup + port/VLAN config complete. FQDN resolves.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | garage-icx-8200 |
| FQDN         | garage-icx-8200.internal.greyrock.io |
| Model        | Ruckus ICX 8200 (ICX8200-C08ZP-POE) |
| Firmware     | 10.0.10g_cd6T253 (Unleashed-managed, T-series) |
| Serial #     | FNR4338U023 |
| Physical location | garage |
| Role         | access (5 APs + 2 SFP+ trunk ports) |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.10/24 (static, on ve 1 / VLAN 1) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 |
| OOB access?  | serial console on /dev/cu.usbserial-10 (9600 8N1); SSH on 10.1.0.10 |
| SSH enabled? | yes (v2, key auth via 1Password ED25519, no password auth) |
| Local users  | admin (Unleashed-created, password hash redacted in committed config) |
| TACACS/RADIUS| none |
| DHCP client  | disabled globally and on ve 1 |

## Physical

- **Uplinks:**
  - 1/2/2 → game room 8200 (10G SFP+, currently UP)
  - 1/2/1 → garage 7150 (10G SFP+, currently DOWN — no cable yet)
- **Stacking:** standalone, 2-port 25G module in slot 2 (not stacked)
- **Power:** single feed; PoE budget 240W available

## VLANs

| VLAN ID | Name    | Purpose  | Ports (tagged)         |
| ------- | ------- | -------- | ---------------------- |
| 1       | mgmt    | native   | all (untagged)         |
| 10      | Internal| trusted  | 1/1/1–1/1/5, 1/2/1, 1/2/2 |
| 20      | Servers | infra    | 1/2/1, 1/2/2 only      |
| 4000    | Guest   | guest    | 1/1/1–1/1/5, 1/2/1, 1/2/2 |

## Port map

| Port  | Name            | What plugs in           | PoE | BPDU guard | Storm ctrl |
| ----- | --------------- | ----------------------- | --- | ---------- | ---------- |
| 1/1/1 | Garage-Rear-AP  | Garage Rear Driveway AP | yes | yes        | 500 pps    |
| 1/1/2 | Garage-Side-AP  | Garage Side Yard AP     | yes | yes        | 500 pps    |
| 1/1/3 | Side-Drive-AP   | Garage Side Driveway AP | yes | yes        | 500 pps    |
| 1/1/4 | Garage-AP       | Garage AP               | yes | yes        | 500 pps    |
| 1/1/5 | Kitchen-AP      | Kitchen AP              | yes | yes        | 500 pps    |
| 1/2/1 | Garage-7150     | Garage 7150 (downlink)  | no  | no         | off        |
| 1/2/2 | GameRoom-8200   | Game Room 8200 (uplink) | no  | no         | off        |
| 1/1/6 | _(none)_        | unused                  | yes | no         | off        |
| 1/1/7 | _(none)_        | unused                  | yes | no         | off        |
| 1/1/8 | _(none)_        | unused                  | yes | no         | off        |

## Conventions for this switch

- Unleashed-managed. Don't propose removing from Unleashed.
- Native VLAN 1 is the mgmt VLAN. Don't change.
- 16-char limit on port-name field.
- APs are BPDU-guarded: if an AP receives a BPDU, it err-disables.
  That's the desired behavior; don't remove.

## Change history

See `/changes/`. Local snapshots live in `config/snapshots/`.

- `2026-06-24-post-port-vlan.txt` — first real config after the
  initial setup. FQDN resolves, all four VLANs in place, ports named.
- `running.txt` — current, scrubbed of password hash and SNMP
  community.
