# network-config

Versioned, offline mirror of the Ruckus ICX (and friends) switch fleet at Greyrock Labs.

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
│   └── sw-XX/                  # one directory per switch, keyed by hostname
│       ├── README.md           # role, model, mgmt IP, physical location
│       ├── config/
│       │   ├── running.txt     # latest `show running-config`
│       │   ├── startup.txt     # latest `show startup-config`
│       │   └── snapshots/      # dated historical captures
│       └── logs/               # session logs, command transcripts
├── topology/                   # site diagrams, VLAN schemes, addressing
├── changes/                    # dated prose notes for each meaningful change
├── scripts/                    # capture/apply helpers
└── .claude/CLAUDE.md           # project-level context for Claude
```

## Workflow per change

1. **Plan** — discuss the change; update `topology/` or per-switch README if
   the design shifts.
2. **Pre-snapshot** — capture current `show run` to
   `switches/sw-XX/config/snapshots/<date>-pre-<topic>.txt`. Commit it.
3. **Apply** — make the change on the live switch via the serial console
   (or out-of-band mgmt when available).
4. **Post-snapshot** — capture the new `show run` to
   `switches/sw-XX/config/snapshots/<date>-post-<topic>.txt` and overwrite
   `running.txt`. Commit.
5. **Document** — write `changes/<date>-<switch>-<topic>.md` describing what
   changed and *why*. Commit.

If anything goes sideways, the pre-snapshot is your rollback: re-apply it via
`scripts/apply-config.sh` or by hand.

## Switches

| Slot                | Hostname           | Role | Model      | Mgmt IP | Status       |
| ------------------- | ------------------ | ---- | ---------- | ------- | ------------ |
| garage-icx-8200     | garage-icx-8200    | TBD  | ICX 8200   | TBD     | unconfigured |
| _sw-02_             | _TBD_              | _TBD_ | _TBD_     | _TBD_   | _new_        |
| _sw-03_             | _TBD_              | _TBD_ | _TBD_     | _TBD_   | _new_        |
| _sw-04_             | _TBD_              | _TBD_ | _TBD_     | _TBD_   | _new_        |
| _sw-05_             | _TBD_              | _TBD_ | _TBD_     | _TBD_   | _new_        |
| _sw-06_             | _TBD_              | _TBD_ | _TBD_     | _TBD_   | _new_        |

Fill in as we go.

## Working with Claude on this repo

At the start of a session, say something like:

> "Let's work on sw-03 in the network-config repo."

Claude will read this repo and orient itself. You shouldn't need to re-explain
the layout, conventions, or current state.
