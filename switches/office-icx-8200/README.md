# office-icx-8200

> **Status:** reset to factory 2026-07-17, then reconfigured for the new Mikrotik-backbone topology. Uplink 1/2/2 → office-crs309. Port 1/2/1 (former downlink to office-icx-7150) removed. UH-AP moved from 1/1/1 to 1/1/6.

## Identity

| Field        | Value |
| ------------ | ----- |
| Hostname     | office-icx-8200 |
| FQDN         | office-icx-8200.internal.greyrock.io |
| Model        | Ruckus ICX 8200 (Unleashed, T-series) |
| Firmware     | 10.0.10g_cd6T253 (RDR10010g_cd6) |
| Serial #     | FNR4338U023 |
| Physical location | office |
| Role         | access |

## Management

| Field        | Value |
| ------------ | ----- |
| Mgmt IP      | 10.1.0.11/24 (static, on ve 1 / VLAN 1) |
| Mgmt VLAN    | 1 (native) |
| Default GW   | 10.1.0.1 (office-rb5009) |
| OOB access?  | serial console |
| SSH enabled? | yes (v2) |
| DHCP client  | disabled |

## Physical

- **Uplinks:**
  - 1/2/2 → office-crs309 (10G SFP+)
- **Downlinks:** none — port 1/2/1 is unused in the new topology (was the
  ICX-to-ICX daisy link to office-icx-7150)
- **Stacking:** standalone, 2-port 25G module in slot 2 (not stacked)

## VLANs

| VLAN ID | Name    | Purpose  | Ports (tagged)         |
| ------- | ------- | -------- | ---------------------- |
| 1       | mgmt    | native   | all (untagged)         |
| 10      | Internal| trusted  | 1/1/5, 1/1/6, 1/1/7, 1/2/2 |
| 20      | Servers | infra    | 1/2/2 tagged; 1/1/7, 1/1/8 untagged |
| 4000    | Guest   | guest    | 1/1/5, 1/1/6, 1/2/2 |

## Port map

| Port  | Name            | What plugs in           | PoE | BPDU guard | Storm ctrl |
| ----- | --------------- | ----------------------- | --- | ---------- | ---------- |
| 1/1/1 | (none)          | unused (UH-AP moved off) | yes | no        | off        |
| 1/1/5 | Office-AP       | AP                     | yes | yes        | 500 pps    |
| 1/1/6 | UH-AP           | upstairs hallway AP    | yes | yes        | 500 pps    |
| 1/1/7 | Kerfuffle       | server (VLAN 20 untagged) | yes | yes        | 500 pps  |
| 1/1/8 | NAS             | server (VLAN 20 untagged) | yes | yes        | 500 pps  |
| 1/2/1 | (none)          | unused (former downlink) | no  | no       | off        |
| 1/2/2 | Office-CRS309   | uplink to office-crs309  | no  | no         | off        |

## Conventions for this switch

- Unleashed-managed. Don't propose removing from Unleashed.
- Native VLAN 1 is the mgmt VLAN. Don't change.
- APs are BPDU-guarded: if an AP receives a BPDU, it err-disables. That's
  the desired behavior; don't remove.
- Uplink 1/2/2 to office-crs309 only. Port 1/2/1 is unused.

## Change history

See `/changes/`. Live config in `config/running.txt`. Snapshots in
`config/snapshots/`.

- `2026-07-17-post-topology-change.txt` — `/show running-config` after
  reconfiguring for the Mikrotik-backbone topology. Mgmt IP changed
  from 10.1.0.14 → 10.1.0.11. Port 1/2/1 (former downlink to
  office-icx-7150) removed from VLANs 10/20/4000 and from interface
  config. Port 1/2/2 port-name changed from "Router" to "Office-CRS309".
- `2026-07-17-post-topology-change-version.txt` — `/show version` output
- `2026-07-17-post-uh-ap-port-move.txt` — `/show running-config` after
  moving UH-AP from 1/1/1 to 1/1/6. Port 1/1/1 reset to default (no
  port-name, no BPDU guard, no broadcast limit). Port 1/1/6 now has the
  UH-AP config. VLAN 10/4000 tagged memberships updated to drop 1/1/1
  and add 1/1/6.
- `2026-07-17-post-stp-priority.txt` — `/show running-config` after
  changing VLAN 1 STP priority from 4096 to 36864 (leaf role: never
  become STP root candidate).
- `2026-07-17-post-querier-demotion.txt` — `/show running-config` after
  demoting VLAN 10 from `multicast active` / `multicast6 active` to
  passive. The IGMP/MLD querier role moved to office-crs309
  (multicast-querier=yes on its bridge); this box now only snoops.