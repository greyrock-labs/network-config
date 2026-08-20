# 2026-08-20 — DNS: add `bootimus.internal.greyrock.io -> 10.1.20.2`

## Why

A new device named `bootimus` is coming online on VLAN 20 (servers) at
`10.1.20.2`. Wanted a stable DNS name so the rest of the fleet can
reach it by name; `10.1.20.2` is in the reserved static range below
the `vlan20-servers` DHCP pool (`.20`–`.254`), so no DHCP reservation
was needed — this is a pure DNS addition.

## What changed (on office-rb5009)

1. **DNS A record** — added a hand-maintained static entry:

   ```
   /ip dns static
   add address=10.1.20.2 name=bootimus.internal.greyrock.io type=A
   ```

   TTL on the live router is 1d, the RouterOS default for hand-added
   records.

## Verification

- `/ip dns static print where name~"bootimus"` → one row,
  `bootimus.internal.greyrock.io  A  10.1.20.2  1d`.
- `/ip dns static print where address=10.1.20.2` → same row,
  confirms no shadow record exists.

## Repo

- `routers/office-rb5009/config/running.txt` — added the A record to
  the hand-maintained infra block in the `/ip dns static` section.
- `routers/office-rb5009/config/snapshots/2026-08-20-bootimus-dns.txt`
  — same content as `running.txt`.