# network-config

Versioned, offline mirror of the Ruckus ICX switch fleet at Greyrock Labs.

## What this repo is

- **Source of truth for switch config** — every change we make to a switch is
  captured back into this repo and committed. The switch's running-config is
  the live state; the repo is the durable record.
- **Backup** — if a switch dies or its config is wiped, we can rebuild from a
  snapshot here.
- **Change log** — every meaningful change gets a file under `changes/` with
  the *why*, not just the *what*.
- **Working memory for Claude** — at the start of a session, point Claude at
  this repo and it can orient itself from the README files, topology notes,
  and recent changes.

## What this repo is NOT

- Not a config-management system (no Ansible/Salt/etc.). Changes are made
  manually on the live switch and then captured.
- Not a replacement for the live running-config. The switch is always
  authoritative for the current state; the repo can lag until a capture runs.

## Layout

```
network-config/
├── switches/
│   └── <hostname>/            # one directory per switch, keyed by hostname
│       ├── README.md          # role, model, mgmt IP, physical location
│       ├── config/
│       │   ├── running.txt    # latest `show running-config` (scrubbed of secrets)
│       │   ├── initial-setup.txt  # the staged config that was applied
│       │   └── snapshots/     # dated historical captures
├── topology/                  # site diagrams, VLAN schemes, addressing
├── changes/                   # dated prose notes for each meaningful change
└── .claude/CLAUDE.md          # project-level context for Claude
```

## Workflow per change

1. **Plan** — discuss the change; update `topology/` or per-switch README if
   the design shifts.
2. **Pre-snapshot** (for non-trivial changes) — capture current `show run` to
   `switches/<hostname>/config/snapshots/<date>-pre-<topic>.txt`. Commit.
3. **Apply** — make the change on the live switch via the serial console
   (or SSH when available). Apply in chunks; verify each chunk.
4. **Post-snapshot** — capture the new `show run`, save to
   `switches/<hostname>/config/snapshots/<date>-post-<topic>.txt` and
   `running.txt`. Commit.
5. **Document** — write `changes/<date>-<switch>-<topic>.md` describing what
   changed and *why*. Commit. Push to Forgejo.

If anything goes sideways, the pre-snapshot is your rollback: re-apply by
hand (the workflow is interactive, no automation scripts).

## Switches

| Hostname           | Role    | Model       | Mgmt IP     | Status        |
| ------------------ | ------- | ----------- | ----------- | ------------- |
| garage-icx-8200    | access  | ICX 8200    | 10.1.0.10   | configured    |
| garage-icx-7150    | access  | ICX 7150    | 10.1.0.11   | configured    |
| _TBD_              | access  | _TBD_       | _TBD_       | _new_         |
| _TBD_              | access  | _TBD_       | _TBD_       | _new_         |
| _TBD_              | access  | _TBD_       | _TBD_       | _new_         |
| _TBD_              | access  | _TBD_       | _TBD_       | _new_         |

All switches are access-layer and managed by Ruckus Unleashed. Fill in the
remaining four as we go — see `topology/greyrock-home.md` for the daisy
chain order.

## Working with Claude on this repo

At the start of a session, say something like:

> "Let's work on game-room-icx-7150 in the network-config repo."

Claude will read this repo and orient itself. You shouldn't need to re-explain
the layout, conventions, or current state.
