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

## Update 2026-07-27: `/certificate settings` reverted

`crl-use=yes` (with `crl-download=yes`) was causing problems, unrelated
to the internal CA. Reverted on the router:

```
/certificate settings set crl-download=no crl-use=no
```

Both are RouterOS defaults, so the `/certificate settings` section
no longer appears in `/export` at all. `running.txt` updated to match
(section removed).

## Status

Still in-progress tinkering, not a finished design. Open questions for
when we pick this back up:
- Router-side `/ip dns` doesn't have `use-doh-server` set — decide
  whether the router itself should resolve via DoH upstream, or DoH is
  purely a thing we're blocking/redirecting for LAN clients.
- Guest VLAN (4000) and mgmt VLAN (1) DNS-FORCE posture — intentional
  exclusion or not decided yet.
- What was actually wrong with `crl-use=yes` — not diagnosed, just
  reverted because it was causing problems.

## Repo

- `config/running.txt` updated to match live state (including the
  `/certificate settings` revert).
- Snapshot: `config/snapshots/2026-07-27-post-doh-forced-dns-wip.txt`
  (pre-revert). No post-revert snapshot taken per user direction.
- No secrets in the diff; `/ip dns static` scrub (house rule) already
  verified consistent with what's live.
