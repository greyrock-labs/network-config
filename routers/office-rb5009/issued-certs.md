# office-rb5009 — issued internal certs

Leaf certs signed by **Grey Rock Intermediate CA** (EC) on office-rb5009,
for internal devices that can't do ACME. Private keys live on the router
and are never committed. **How to issue one:** `ca-issuing-runbook.md`.
CA design + rationale: `changes/2026-07-22-office-rb5009-internal-ca-rebuild.md`.

All leaves: EC P-256, `key-usage=digital-signature,key-encipherment,tls-server`
(never `key-cert-sign`), signed off the intermediate. Keep validity **≤825
days** (Safari's hard cap for user-installed-root chains; the public 398-day
limit does not apply to a private CA).

| RouterOS name | CN | SANs | Key | Issued | Expires | Serial | Used by |
|---------------|----|----|-----|--------|---------|--------|---------|
| `office-rb5009` | office-rb5009.internal.greyrock.io | DNS:office-rb5009.internal.greyrock.io, IP:10.1.0.1, IP:10.1.10.1, IP:10.1.20.1 | EC P-256 | 2026-07-22 | 2028-07-21 | `2A77F1197B0D68C3` | router www-ssl / api-ssl |
| `Ruckus Unleashed` | unleashed.internal.greyrock.io | DNS:unleashed.internal.greyrock.io, IP:10.1.10.7 | EC P-256 | 2026-07-22 | 2028-07-21 | `1A3760AFB5510B7E` | Ruckus Unleashed controller (10.1.10.7) |

SHA-256 fingerprints:
- office-rb5009: `898e9f8693298d968f3dd89558ff58d5cedadfc3d7188f2f9f7d052b2226c0c1`
- Ruckus Unleashed: `b04fa5ada98e94ab95316c475eac31ac2579103ae8c71355c2ba302cd35e7bde`

## Renewal

These expire **2028-07-21**. Re-issue with the recipe in the CA-rebuild
changes doc (same name/CN/SANs), re-export, and re-install on the device.
