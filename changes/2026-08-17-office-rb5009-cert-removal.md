# 2026-08-17 — office-rb5009: replace internal CA with external CA cert

## Why

The Grey Rock internal CA (Root + Intermediate) and all nine leaf
certificates it signed were removed from the router. The CA workflow
was too tedious for the value it provided; certificates will be
re-issued from a different CA elsewhere.

The router's own cert (`office-rb5009.internal.greyrock.io`) was
immediately replaced with one issued by the new CA so `www-ssl` and
`api-ssl` don't serve RouterOS's default self-signed cert. The other
eight hostnames remain to be re-issued from the new CA at their own
pace.

The hostname list of certs that were covered by the old CA, for
re-creation:

- office-rb5009.internal.greyrock.io *(re-issued — done)*
- unleashed.internal.greyrock.io
- courtyard-porch-doorbell.internal.greyrock.io
- garage-camera-side-yard.internal.greyrock.io
- garage-camera-todd.internal.greyrock.io
- garage-camera-andy.internal.greyrock.io
- kvm-homeassistant.internal.greyrock.io
- kvm-codswallop.internal.greyrock.io
- kvm-kerfuffle.internal.greyrock.io

## What changed

**On the router — removal:**

1. Unset the `certificate=` reference on `www-ssl` and `api-ssl` so
   removing the cert objects wouldn't break both services.
2. Removed all certificate objects including the Root CA, Intermediate
   CA, and every leaf.

**On the router — import:**

3. Uploaded two PEM files from the new CA to the router's Files:
   `office-rb5009.internal.greyrock.io_chain.pem` (server cert +
   intermediate) and `office-rb5009.internal.greyrock.io_private.pem`
   (private key).
4. Imported both via `/certificate import` (passphrase empty).
5. Renamed the imported server cert from the auto-generated
   `office-rb5009.internal.greyrock.io_chain.pem_0` to `office-rb5009`
   to match the existing `/ip service` references.
6. Assigned `certificate=office-rb5009` back to `www-ssl` and
   `api-ssl`.

`/certificate print` after import:

```
Flags: K - PRIVATE-KEY; T - TRUSTED
  0 KT office-rb5009   all   office-rb5009.internal.greyrock.io  DNS:office-rb5009.internal.greyrock.io
  1  T ...              all   Grey Rock Intermediate CA
```

Entry 0 is the leaf (has `K` = private key, `T` = trusted). Entry 1 is
the intermediate (trusted, no key — correct). The intermediate is still
named "Grey Rock Intermediate CA" because it was bundled in the chain
PEM; that's just the CN from the new CA's intermediate, not a leftover
from the old CA.

**In the export:** only the timestamp changed. The
`certificate=office-rb5009` references on `www-ssl` and `api-ssl` are
identical to the pre-removal capture — the cert *object* behind that
name is from a different CA, but `/export` never emits cert objects,
only the name reference. The `/certificate settings` line
(`set builtin-trust-store=all`) is unchanged.

**In the repo:**

- Deleted `runbooks/ca-issuing-runbook.md` — the CA issuing runbook.
- Deleted `routers/office-rb5009/issued-certs.md` — the cert registry.
- `README.md` — removed the runbook from the layout tree.
- `topology/vlan60-cameras.md` — removed two cert follow-up notes
  (the "re-issue camera certs with new VLAN 60 IPs" deferred items).
- Historical `changes/*.md` docs that reference the CA are left intact
  — they record what happened, not what is.

## Verified

- `/certificate print` — one leaf (`KT`, correct CN/SAN) + one
  intermediate (`T`, no key).
- `/export` — `certificate=office-rb5009` on both `www-ssl` and
  `api-ssl`.
- No leftover cert objects from the old CA.

## Notes for the next reader

- The remaining eight hostnames still need certs from the new CA. The
  three garage cameras and the courtyard doorbell moved to VLAN 60
  since their original certs were issued — use the current IPs
  (10.1.60.x), not the old VLAN 10 addresses.
- The imported chain PEM included the new CA's intermediate, which
  RouterOS imported as a separate trusted cert entry. That's expected
  and correct — the router needs to trust it to validate the chain.
