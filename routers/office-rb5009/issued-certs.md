# office-rb5009 — issued internal certs

Leaf certs signed by **Grey Rock Intermediate CA** (EC) on office-rb5009,
for internal devices that can't do ACME. Private keys live on the router
and are never committed. **How to issue one:** `../../runbooks/ca-issuing-runbook.md`.
CA design + rationale: `changes/2026-07-22-office-rb5009-internal-ca-rebuild.md`.

Leaves are EC P-256 by default, `key-usage=digital-signature,key-encipherment,tls-server`
(never `key-cert-sign`), signed off the intermediate. Keep validity **≤825
days** (Safari's hard cap for user-installed-root chains; the public 398-day
limit does not apply to a private CA).

**Exception — RSA:** some appliances reject EC. Reolink's HTTPS web service
only accepts **RSA** (upload just says "failed" for an EC cert). Issue those
leaves with `key-size=2048` (numeric = RSA) off the same intermediate.

**Exception — signed off the ROOT:** some devices serve only the leaf and
won't present the intermediate (their "CA Certificate" import slot is a
client-trust store, not a chain-serving slot — verified on Hikvision). A
leaf issued off the intermediate then fails `21 unable to verify` because
clients trust the root, not the intermediate. Fix: sign those leaves
directly off the root (`ca="Grey Rock Root CA"`) so the served leaf-only
chain validates against the root clients already trust.

| RouterOS name | CN | SANs | Key | Issued | Expires | Serial | Used by |
|---------------|----|----|-----|--------|---------|--------|---------|
| `office-rb5009` | office-rb5009.internal.greyrock.io | DNS:office-rb5009.internal.greyrock.io, IP:10.1.0.1, IP:10.1.10.1, IP:10.1.20.1 | EC P-256 | 2026-07-22 | 2028-07-21 | `2A77F1197B0D68C3` | router www-ssl / api-ssl |
| `Ruckus Unleashed` | unleashed.internal.greyrock.io | DNS:unleashed.internal.greyrock.io, IP:10.1.10.7 | EC P-256 | 2026-07-22 | 2028-07-21 | `1A3760AFB5510B7E` | Ruckus Unleashed controller (10.1.10.7) |
| `courtyard-porch-doorbell` | courtyard-porch-doorbell.internal.greyrock.io | DNS:courtyard-porch-doorbell.internal.greyrock.io, IP:10.1.10.96 | **RSA 2048** | 2026-07-23 | 2028-07-22 | `47158511E4DEEB01` | Reolink PoE doorbell (10.1.10.96, garage-icx-7150 port 1/1/1) — RSA: Reolink rejects EC |
| `garage-camera-side-yard` | garage-camera-side-yard.internal.greyrock.io | DNS:garage-camera-side-yard.internal.greyrock.io, IP:10.1.10.133 | EC P-256 | 2026-07-23 | 2028-07-22 | `10A0056A0AB14050` | Hikvision camera (10.1.10.133) — signed off **root** (serves leaf-only, can't present the intermediate) |

SHA-256 fingerprints:
- office-rb5009: `898e9f8693298d968f3dd89558ff58d5cedadfc3d7188f2f9f7d052b2226c0c1`
- Ruckus Unleashed: `b04fa5ada98e94ab95316c475eac31ac2579103ae8c71355c2ba302cd35e7bde`
- courtyard-porch-doorbell: `c215449a37c7618ecaa0abc5ee8e9335a7b70dd6589f76e7faee9ae1802276ed`
- garage-camera-side-yard: `b3382546916505517db5abb3b614f2da83d999e0f8032aaf7ce65d21b2d81435`

## Renewal

These expire **2028-07-21**. Re-issue with the recipe in the CA-rebuild
changes doc (same name/CN/SANs), re-export, and re-install on the device.
