# Greyrock home network topology

2026-07-17 snapshot of the live network.

## High-level

The home network is a two-tier design:

- **Backbone (Mikrotik):** the office-rb5009 router and three CRS309s
  form an SFP+ daisy chain spanning the office, game room, and garage.
- **Access (Ruckus ICX):** each room has two ICX switches. Each ICX
  uplinks to the CRS309 in its room via a single SFP+.

```
                       (Mikrotik spine, SFP+ daisy chain)

  office-rb5009 --SFP+--> office-crs309 --SFP+--> game-room-crs309 --SFP+--> garage-crs309
                      | SFP+                | SFP+                  | SFP+
                      v                     v                       v

                 office-icx-8200      game-room-icx-8200        garage-icx-8200
                 office-icx-7150      game-room-icx-7150        garage-icx-7150
```

The office-rb5009 has no leaves. Every ICX is a leaf of the CRS309 in its room.

## Devices

### Backbone (Mikrotik)

| Hostname            | Model           | Location  | Mgmt IP |
| ------------------- | --------------- | --------- | ------- |
| office-rb5009       | RB5009          | office    | TBD     |
| office-crs309       | CRS309-1G-8S+   | office    | TBD     |
| game-room-crs309    | CRS309-1G-8S+   | game room | TBD     |
| garage-crs309       | CRS309-1G-8S+   | garage    | TBD     |

### Access (Ruckus ICX)

| Hostname            | Model    | Room      | Mgmt IP   | Uplink to        | SFP+ port |
| ------------------- | -------- | --------- | --------- | ---------------- | --------- |
| garage-icx-8200     | ICX 8200 | garage    | 10.1.0.10 | garage-crs309    | 1/2/_     |
| garage-icx-7150     | ICX 7150 | garage    | 10.1.0.11 | garage-crs309    | TBD       |
| game-room-icx-8200  | ICX 8200 | game room | 10.1.0.12 | game-room-crs309 | TBD       |
| game-room-icx-7150  | ICX 7150 | game room | 10.1.0.13 | game-room-crs309 | TBD       |
| office-icx-8200     | ICX 8200 | office    | 10.1.0.14 | office-crs309    | TBD       |
| office-icx-7150     | ICX 7150 | office    | 10.1.0.15 | office-crs309    | TBD       |

All ICX switches are Unleashed-managed (do not remove from Unleashed).
Each ICX has one SFP+ uplink to its room's CRS309; the second SFP+ on
the ICX (where present) is unused.

## VLAN scheme

VLAN 1 is native / mgmt on every switch port.

| VLAN | Name | Purpose |
| --- | --- | --- |
| 1 | Management | Native VLAN on all switch ports |
| 10 | Internal | Trusted LAN traffic |
| 20 | Servers | Server/infra segment |
| 4000 | Guest | Guest WiFi (APs tag this) |

Default gateway on the access switches is `10.1.0.1`, on office-rb5009.

## APs and their switch ports

See each per-switch `switches/<hostname>/README.md` for the port-to-AP
map. APs attach to ICX access ports (1/1/x on the 8200s, equivalent on
the 7150s) and tag VLAN 4000 for guest traffic.