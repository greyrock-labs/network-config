# office-rb5009: DHCP reservation + DNS for garage-camera-todd

2026-07-31

## Why

Todd installed a new camera in the garage. It pulled a dynamic lease
on VLAN 10 (Internal) at `10.1.10.66`. We want that address reserved
so it survives lease expiry / reboot, and a stable DNS name so it can
be reached at `garage-camera-todd.internal.greyrock.io`.

## What changed (on office-rb5009)

1. **DHCP reservation** — added a static lease on `dhcp-vlan10`:
   ```
   /ip dhcp-server lease
   add address=10.1.10.66 mac-address=74:3F:C2:E7:EB:78 \
       server=dhcp-vlan10 comment="Garage Camera - Todd"
   ```
   Removed the pre-existing dynamic lease for the same address so the
   static entry binds cleanly on next DHCP cycle.

2. **DNS A record** — added a static DNS entry:
   ```
   /ip dns static
   add address=10.1.10.66 name=garage-camera-todd.internal.greyrock.io type=A
   ```
   (TTL on the live router is 1d, the RouterOS default for hand-added
   records.)

## Verification

- `/ip dhcp-server lease print detail where address=10.1.10.66` →
  static entry present, status `waiting` (expected — binds on next
  DHCP request from the camera).
- `/ip dns static print where address=10.1.10.66` →
  `garage-camera-todd.internal.greyrock.io  A  10.1.10.66  1d`

## Repo

Updated `routers/office-rb5009/config/running.txt` — added the lease
line (VLAN 10 block) and the DNS A record (hand-maintained infra
records block).