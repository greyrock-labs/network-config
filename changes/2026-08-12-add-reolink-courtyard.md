# 2026-08-12 — VLAN 60: add courtyard-porch-doorbell (Reolink) at .13

## Why

A new Reolink camera came online at the courtyard porch. It picked
up a dynamic lease on `dhcp-vlan60` at `10.1.60.251` (top-down
assignment from RouterOS) and bound immediately — the segment
worked. Wanted a stable address and DNS name so the rest of the
fleet can reach it by name and so the address doesn't churn on every
lease cycle, same pattern as the three named Hikvisions.

## What changed (on office-rb5009)

1. **DHCP reservation** — replaced the dynamic lease at `.251` with a
   static entry on `dhcp-vlan60`:

   ```
   /ip dhcp-server lease
   add address=10.1.60.13 comment="Courtyard Porch Doorbell" \
       mac-address=EC:71:DB:9B:DE:A9 server=dhcp-vlan60
   /ip dhcp-server lease remove [find where address=10.1.60.251]
   ```

   The dynamic `.251` entry was removed so the static `.13` binds
   cleanly on the camera's next DHCP cycle — same pattern as the
   original 2026-07-31 reservations change.

2. **DNS A record** — added a static entry:

   ```
   /ip dns static
   add address=10.1.60.13 name=courtyard-porch-doorbell.internal.greyrock.io type=A
   ```

   TTL on the live router is 1d, the RouterOS default for hand-added
   records.

## Verification

- `/ip dhcp-server lease print where address=10.1.60.13` → static
  entry present, `status=bound` (`LAST-SEEN=10s` at apply time).
- `/ip dhcp-server lease print where address=10.1.60.251` → empty
  (the dynamic lease was removed cleanly).
- `/ip dns static print where name~"courtyard-porch-doorbell"` → one
  row, `courtyard-porch-doorbell.internal.greyrock.io  A  10.1.60.13
  1d`.

## Repo

- `routers/office-rb5009/config/running.txt` — added the lease line
  in the VLAN 60 reservation block and the DNS A record in the
  hand-maintained infra block.
- `routers/office-rb5009/config/snapshots/2026-08-12-add-reolink-courtyard.txt`
  — same content as `running.txt`. The earlier
  `2026-08-12-post-vlan60.txt` snapshot stays frozen at the pre-Reolink
  state, as a snapshot should.
- `topology/vlan60-cameras.md` — added the Reolink row to the
  reservations table (`.13`) and recorded it on port 1/1/1.
- `switches/garage-icx-7150/README.md` — port map records the Reolink
  on 1/1/1. It replaced the previous device on that port; no switch
  config changed.