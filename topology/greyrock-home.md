# Greyrock home network topology

2026-06-24 snapshot. Updates as the network changes.

## Daisy chain (the long and winding SFP+)

The home network is a daisy chain of access switches between the
router and the rest of the house, with only 2 SFP+ ports per switch:

```
router
  └── office 8200
        └── office 7150
              └── game room 8200
                    └── game room 7150
                          └── garage 8200      (this repo)
                                └── garage 7150
```

This is intentional. Each switch is daisychained to the next via its
two SFP+ ports. Designed for a house, not a data center.

## VLAN scheme

| VLAN | Name       | Purpose                            |
| ---- | ---------- | ---------------------------------- |
| 1    | Management | Native VLAN on all switch ports    |
| 10   | Internal   | Trusted LAN traffic                |
| 20   | Servers    | Server/infra segment               |
| 4000 | Guest      | Guest WiFi (APs tag this)          |

## Switches

| Hostname           | Model              | Role               | Repo dir |
| ------------------ | ------------------ | ------------------ | -------- |
| garage-icx-8200    | ICX 8200           | Access (APs)       | switches/garage-icx-8200/ |
| _(other 5)_        |                    |                    |          |

(Fill in the rest as we go through them.)

## APs and their switch ports

See per-switch README.md for port-to-device maps.
