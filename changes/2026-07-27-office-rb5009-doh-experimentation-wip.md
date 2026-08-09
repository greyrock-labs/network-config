# 2026-07-27 — office-rb5009: DoH experimentation (WIP, captured mid-flight)

Live config had drifted from the repo — changes made directly on the
router while poking at DNS-over-HTTPS, not yet documented anywhere.
This note just catches the repo up to what's live; the actual DoH
project (client-side rollout, policy decisions) is still ahead of us.

## What changed on the router (undocumented until now)

- **`/certificate settings`**: `crl-download=yes crl-use=yes` — new
  section, wasn't in the repo at all before.
- **`/ip dns`**: added `doh-max-concurrent-queries=100`,
  `doh-max-server-connections=100`, `max-concurrent-queries=200`,
  `max-concurrent-tcp-sessions=200`, `verify-doh-cert=yes`. The router
  itself doesn't have `use-doh-server` set yet, so it's not actually
  issuing DoH queries upstream — these look like prep/tuning ahead of
  turning that on.
- **`DNS-FORCE` interface list** (members: `bridge`, `vlan10`,
  `vlan20`) + two new `/ip firewall nat` `dstnat` redirect rules that
  hairpin any port-53 traffic (UDP+TCP) originating on those VLANs
  back to the router's own resolver. This is the piece that matters
  most for the eventual DoH design: it stops LAN clients from
  bypassing the router's DNS policy via their own hardcoded resolvers
  (e.g. a phone or IoT device configured to hit 8.8.8.8 or a public
  DoH endpoint directly) — same intent as most "force DNS" setups,
  just via NAT instead of firewall drop.

VLAN 4000 (guest) and VLAN 1 (mgmt/bridge is a partial exception — see
below) are **not yet** forced. `bridge` is a DNS-FORCE member (so VLAN
1 mgmt traffic is included) but VLAN 4000 (guest) deliberately is not.

## Status

This is a snapshot of in-progress tinkering, not a finished design.
Known open questions for when we pick this back up:
- Is `crl-use=yes` actually needed/wanted given the internal CA setup
  from `2026-07-22-office-rb5009-internal-ca-rebuild.md`, or is CRL
  checking going to fail closed against internal-only leaves that
  don't publish a CRL endpoint?
- Router-side `/ip dns` doesn't have `use-doh-server` set — decide
  whether the router itself should resolve via DoH upstream, or DoH is
  purely a thing we're blocking/redirecting for LAN clients.
- Guest VLAN (4000) and mgmt VLAN (1) DNS-FORCE posture — intentional
  exclusion or not decided yet.

## Repo

- `config/running.txt` updated to match live state.
- Snapshot: `config/snapshots/2026-07-27-post-doh-forced-dns-wip.txt`.
- No secrets in the diff; `/ip dns static` scrub (house rule) already
  verified consistent with what's live.
