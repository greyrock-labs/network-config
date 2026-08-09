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
| `office-rb5009` | office-rb5009.internal.greyrock.io | DNS:office-rb5009.internal.greyrock.io, IP:10.1.0.1, IP:10.1.10.1, IP:10.1.20.1 | EC P-256 | 2026-08-09 | 2028-08-08 | `2CABE1AE663964CD` | router www-ssl / api-ssl |
| `Ruckus Unleashed` | unleashed.internal.greyrock.io | DNS:unleashed.internal.greyrock.io, IP:10.1.10.7 | EC P-256 | 2026-07-22 | 2028-07-21 | `1A3760AFB5510B7E` | Ruckus Unleashed controller (10.1.10.7) |
| `courtyard-porch-doorbell` | courtyard-porch-doorbell.internal.greyrock.io | DNS:courtyard-porch-doorbell.internal.greyrock.io, IP:10.1.10.96 | **RSA 2048** | 2026-07-23 | 2028-07-22 | `47158511E4DEEB01` | Reolink PoE doorbell (10.1.10.96, garage-icx-7150 port 1/1/1) — RSA: Reolink rejects EC |
| `garage-camera-side-yard` | garage-camera-side-yard.internal.greyrock.io | DNS:garage-camera-side-yard.internal.greyrock.io, IP:10.1.10.133 | EC P-256 | 2026-07-23 | 2028-07-22 | `10A0056A0AB14050` | Hikvision camera (10.1.10.133) — signed off **root** (serves leaf-only, can't present the intermediate) |
| `kvm-homeassistant` | kvm-homeassistant.internal.greyrock.io | DNS:kvm-homeassistant.internal.greyrock.io | **RSA 2048** | 2026-07-28 | 2028-07-27 | `10EF271B16B58749` | Supermicro IPMI/BMC — RSA: rejects EC; signed off **root** (serves leaf-only, can't present the intermediate) |
| `kvm-codswallop` | kvm-codswallop.internal.greyrock.io | DNS:kvm-codswallop.internal.greyrock.io | EC P-256 | 2026-07-28 | 2028-07-27 | `54D3D57D17C70922` | JetKVM (modern, standard recipe — presents full chain) |
| `kvm-kerfuffle` | kvm-kerfuffle.internal.greyrock.io | DNS:kvm-kerfuffle.internal.greyrock.io | EC P-256 | 2026-07-28 | 2028-07-27 | `F6BE606846646B` | JetKVM (modern, standard recipe — presents full chain) |
| `garage-camera-todd` | garage-camera-todd.internal.greyrock.io | DNS:garage-camera-todd.internal.greyrock.io, IP:10.1.10.66 | EC P-256 | 2026-07-31 | 2028-07-30 | `53973909E3635469` | Hikvision camera (10.1.10.66) — signed off **root** (serves leaf-only, can't present the intermediate) |
| `garage-camera-andy` | garage-camera-andy.internal.greyrock.io | DNS:garage-camera-andy.internal.greyrock.io, IP:10.1.10.68 | EC P-256 | 2026-07-31 | 2028-07-30 | `416AD26D799A7A22` | Hikvision camera (10.1.10.68) — signed off **root** (serves leaf-only, can't present the intermediate) |

SHA-256 fingerprints:
- office-rb5009: `e5abca93d872e710239f16c6137ab14f73dfe39f28218132b6c3557af38d7825`
- Ruckus Unleashed: `b04fa5ada98e94ab95316c475eac31ac2579103ae8c71355c2ba302cd35e7bde`
- courtyard-porch-doorbell: `c215449a37c7618ecaa0abc5ee8e9335a7b70dd6589f76e7faee9ae1802276ed`
- garage-camera-side-yard: `b3382546916505517db5abb3b614f2da83d999e0f8032aaf7ce65d21b2d81435`
- kvm-homeassistant: `7c2569aac252850fdbad130f5401cc8dc9eac42ae1e888ed0b147d72e1e642f7`
- kvm-codswallop: `7315bcaf6a9b82908c06a957e614039ee00c122806816ea60c4f470b8539ae6d`
- kvm-kerfuffle: `ebbfa23839bab6127706cbc4e75a0a06286833b7c757996bb40291f4fe459843`
- garage-camera-todd: `ce0b613fbfde0a36bc3f7f3cf9569eafe971350ff554555440c2846467fd0ca4`
- garage-camera-andy: `5b309947e2fbfbd6b7c248a2f16e1c18300466f298c4e9f39bbed2a66758dcf2`

## Renewal

These expire **2028-07-21**. Re-issue with the recipe in the CA-rebuild
changes doc (same name/CN/SANs), re-export, and re-install on the device.
