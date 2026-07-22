# network-config

Versioned, offline mirror of the Greyrock Labs network fleet: a
MikroTik router + spine (RouterOS) and Ruckus ICX access switches
(FastIron, Unleashed-managed).

## What this repo is

- **Source of truth for device config** — every change made to a device
  is captured back into this repo and committed. The device's running
  config is the live state; the repo is the durable record.
- **Backup** — if a device dies or its config is wiped, we rebuild from
  a capture here.
- **Change log** — every meaningful change gets a file under `changes/`
  with the *why*, not just the *what*.
- **Working memory for Claude** — at the start of a session, point
  Claude at this repo and it orients itself from the README files,
  topology notes, and recent changes.

## What this repo is NOT

- Not a config-management system (no Ansible/Salt/etc.). Changes are
  made manually on the live device and then captured.
- Not a replacement for the live running config. The device is always
  authoritative for current state; the repo can lag until a capture.

## Layout

```
network-config/
├── routers/                   # one directory per RouterOS router/gateway
│   └── <hostname>/
│       ├── README.md          # role, model, mgmt IP, physical location
│       ├── config/
│       │   ├── running.txt    # latest capture (scrubbed of secrets)
│       │   └── snapshots/     # dated historical captures
├── switches/                  # one directory per switch (CRS/ICX)
│   └── <hostname>/
│       ├── README.md
│       ├── config/
│       │   ├── running.txt
│       │   └── snapshots/
├── topology/                  # site topology, VLAN scheme, fleet templates
│   ├── greyrock-home.md       # the network: spine, leaves, VLANs, addressing
│   └── crs309-base-config.md  # CRS309 fleet template + apply-order + validation
├── runbooks/                  # operational how-to guides
│   ├── multicast-runbook.md   # how to inspect IGMP/MLD on both platforms
│   └── ca-issuing-runbook.md  # issue an internal TLS cert from the Grey Rock CA
├── changes/                   # dated prose notes for each meaningful change
└── .claude/CLAUDE.md          # project-level context for Claude
```

## The fleet

Topology: `office-rb5009 → office-crs309 → game-room-crs309 →
garage-crs309` (10G SFP+ spine); each room's ICX pair are leaves of the
room's CRS309. Full detail in `topology/greyrock-home.md`.

### Router (MikroTik, RouterOS)

| Hostname       | Role                                     | Model   | Mgmt IP    | Status |
| -------------- | ---------------------------------------- | ------- | ---------- | ------ |
| office-rb5009  | gateway, L3 routing, DHCP, DNS, firewall, eBGP to k8s | RB5009  | 10.1.0.1   | in production |

### Spine (MikroTik, RouterOS)

| Hostname            | Role              | Model          | Mgmt IP    | Status |
| ------------------- | ----------------- | -------------- | ---------- | ------ |
| office-crs309       | spine, STP root, mcast querier | CRS309-1G-8S+ | 10.1.0.10 | in production |
| game-room-crs309    | spine             | CRS309-1G-8S+  | 10.1.0.13  | in production |
| garage-crs309       | spine, end        | CRS309-1G-8S+  | 10.1.0.16  | in production |

### Access (Ruckus ICX, Unleashed)

| Hostname            | Role    | Model     | Mgmt IP    | Status |
| ------------------- | ------- | --------- | ---------- | ------ |
| office-icx-8200     | access  | ICX 8200  | 10.1.0.11  | in production |
| office-icx-7150     | access  | ICX 7150  | 10.1.0.12  | in production |
| game-room-icx-8200  | access  | ICX 8200  | 10.1.0.14  | in production |
| game-room-icx-7150  | access  | ICX 7150  | 10.1.0.15  | in production |
| garage-icx-8200     | access  | ICX 8200  | 10.1.0.17  | in production |
| garage-icx-7150     | access  | ICX 7150  | 10.1.0.18  | in production |

All six ICX are now cut over to the Mikrotik spine — each has a single
uplink to its room's CRS309 (no ICX-to-ICX links), leaf STP priority
36864, and passive multicast. The fleet renumber that ran alongside the
cutover is complete.

## Workflow per change

1. **Plan** — discuss the change; update `topology/` or the per-device
   README if the design shifts.
2. **Pre-snapshot** (for non-trivial changes) — capture the current
   config to `routers/<hostname>/config/snapshots/<date>-pre-<topic>.txt`
   or `switches/<hostname>/config/snapshots/...` depending on the
   device type.
3. **Apply** — make the change on the live device (ICX: serial/SSH
   paste; MikroTik: Winbox/SSH). Apply in chunks; verify each chunk.
4. **Post-snapshot** — capture the new config to
   `snapshots/<date>-post-<topic>.txt` AND overwrite `running.txt`.
   Scrub secrets before committing — no real password hashes or SNMP
   communities in the repo, use `<REDACTED-*>` placeholders.
5. **Document** — write `changes/<date>-<topic>.md` with the why.
6. **Commit.** Push when asked.

If anything goes sideways, the pre-snapshot is the rollback: re-apply
by hand (the workflow is interactive, no automation).

## Working with Claude on this repo

At the start of a session, say something like:

> "Let's work on game-room-icx-8200 in the network-config repo."

Claude reads this repo and orients itself. You shouldn't need to
re-explain the layout, conventions, or current state.