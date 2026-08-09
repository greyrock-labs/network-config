# 2026-07-27 — office-rb5009: ctrld container replaces built-in resolver as the fleet's DNS server

## Why

The DoH/DNS-force experimentation from earlier today (see
`2026-07-27-office-rb5009-doh-experimentation-wip.md`) was prep work for this:
replacing the router's own DNS resolver with a Control D (`ctrld`) container,
so we get DoH/DoT upstream, per-client visibility in the Control D dashboard,
and per-VLAN filtering policy — none of which the RouterOS built-in resolver
(behind `use-doh-server`) could give us.

## What changed

### New VLAN 30 for containers
- `10.1.30.0/24`, router at `10.1.30.1`, local to the rb5009 only (not
  trunked to the switches — no access ports need it).
- Added to the `LAN` interface list (required — otherwise the input-chain
  `drop all not coming from LAN` rule blocks the container's own queries to
  the router). Deliberately **not** added to `DNS-FORCE` — that list is for
  client segments we want to force through the resolver; forcing the
  resolver's own subnet would create a self-redirect loop.

### ctrld container
- USB stick (Samsung 128GB) formatted `ext4` as `usb1` for container
  storage (`root-dir=/usb1/ctrld-root`, config mounted from `/usb1/ctrld`).
- Container's `veth1` given a **real routable IP** (`10.1.30.20`) on vlan30
  rather than a NAT'd private container network — deliberate choice so
  ctrld sees real client IPs directly, no masquerade needed for egress.
- `ctrld.toml` (`routers/office-rb5009/config/ctrld.toml`) implements
  per-VLAN Control D resolver profiles:
  - `10.1.10.0/24` (Internal) → resolver `5bj0g131ip`
  - `10.1.0.0/24` + `10.1.20.0/24` (Minimal) → resolver `18omwwxv3la`
  - `192.168.23.0/24` (Guest) → resolver `dihmae97cq`
  - A domain rule (evaluated before the per-network fallback, per ctrld's
    `rules => macs => networks` precedence) sends `greyrock.io` /
    `*.greyrock.io` to the router's own built-in resolver
    (`10.1.30.1:53`) instead, so internal static records
    (`*.internal.greyrock.io`, switches, infra) keep resolving.
  - IPv6 client-facing resolution was tried and reverted: LAN client IPv6
    addresses aren't in reverse DNS, so ctrld couldn't attribute queries to
    a device the way it can over IPv4 (loses the Control D dashboard
    per-client visibility). Listener is IPv4-only (`0.0.0.0:53`).
  - vlan30 still got a GUA (from the existing `spectrum-v6` delegated
    prefix, same convention as the other VLANs) purely so ctrld itself can
    reach Control D over IPv6 if it prefers to for its own upstream
    connections — not for serving clients.
- `start-on-boot=yes` set so a router reboot doesn't leave the whole house
  without DNS.

### DNS-FORCE cutover
- The existing `DNS-FORCE` NAT hairpin (`bridge`, `vlan10`, `vlan20`) was
  retargeted from `action=redirect` (self) to `action=dst-nat
  to-addresses=10.1.30.20` — DNS-FORCE'd traffic now goes to ctrld, not the
  router's own resolver.
- `vlan4000` (guest) was added to `DNS-FORCE` for the first time (this was
  an open question in the earlier WIP note) — guest DNS is now forced
  through ctrld too, using the dedicated Guest resolver profile.
- Guest isolation needed an explicit carve-out: the existing
  `10.1.0.0/16` "internal" address-list (used by the guest-isolation drop
  rule) covers `10.1.30.0/24`, so without an exception guest devices would
  have been unable to reach the container at all. Added two accept rules
  (udp/tcp, dst `10.1.30.20:53`) ahead of the isolation drop.

### DHCP / NTP
- All four `/ip dhcp-server network` entries now hand out `10.1.30.20` as
  `dns-server` directly (previously each VLAN's own router address) — ctrld
  is now the primary DHCP-assigned resolver, not just a NAT backstop.
- `vlan1`/`vlan10`/`vlan20` DHCP networks now also hand out
  `ntp-server=10.1.20.16,17,18,19` (the four internal NTP boxes). Guest
  intentionally left off.
- `/ipv6/nd advertise-dns` changed from `self` to `no` — stopped advertising
  an IPv6 DNS resolver via RA at all, consistent with the IPv6-client-DNS
  revert above.

### Switch fleet DNS server update
All 9 switches (3 CRS309s + 6 ICX) previously pointed their own DNS
resolver config at `10.1.0.1` (the rb5009's bridge address) — updated to
`10.1.30.20` to match. CRS309s: `/ip dns set servers=10.1.30.20`. ICX:
`ip dns server-address 10.1.30.20` / `no ip dns server-address 10.1.0.1`
(the ICX command appends rather than replaces, so the `no` form was
needed to drop the old entry).

While capturing these, found the repo copies had drifted independent of
tonight's change:
- Several ICX switches' saved configs were missing a second
  `snmp-server community` line that's live on the device.
- `game-room-icx-7150`'s saved config was missing `cli timeout 0` and the
  `snmp-server community` lines entirely — captured fresh from the live
  device rather than patched.

## Known gaps / follow-ups
- FORCERENEW (`Use Reconfigure` in WinBox) was discussed but not yet
  enabled anywhere — client-side support for it is spotty, so it wouldn't
  guarantee faster pickup of the new DHCP options everywhere.
- `Add DNS Entries For Leases` (the built-in RouterOS lease-DNS feature)
  was deliberately left off — it would conflict/duplicate with the
  existing custom `dhcp-dns-register` lease-script.
- What was actually wrong with `crl-use=yes` (reverted earlier today) is
  still undiagnosed — unrelated to tonight's work, just still open.

## Repo
- `routers/office-rb5009/config/running.txt` — updated to full current
  state.
- `routers/office-rb5009/config/snapshots/2026-07-27-post-ctrld-container-vlan30.txt`
  — post-change snapshot.
- `routers/office-rb5009/config/ctrld.toml` — new, the container's config.
- All 9 switches: `running.txt` updated, `config/snapshots/2026-07-27-post-ctrld-dns-cutover.txt`
  added.
- Secrets scrubbed per house rules (password hashes, SNMP community
  strings, RoMON secret, dynamic `/ip dns static` entries).
