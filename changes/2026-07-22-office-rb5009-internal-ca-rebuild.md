# 2026-07-22 — office-rb5009: internal CA rebuilt from scratch (EC)

Rebuilt the on-router MikroTik CA that acts as the internal CA for the
network. The first attempt had a broken leaf and a light root; this is
the clean redo. The CA signs TLS leaf certs for internal appliances
that can't do ACME (cameras, Ruckus Unleashed, the router's own mgmt
TLS, etc.). **k8s is out of scope** — cluster TLS is handled in-cluster.

## Why (problems with the first attempt)

1. **Leaf was itself a CA.** The old `Grey Rock Router` leaf had the
   `A` (authority) flag and `key-usage=…,key-cert-sign,crl-sign` — a
   server cert that could sign other certs. Wrong and over-privileged.
2. **Leaf SAN didn't match reality.** CN/SAN was
   `grey-rock-router.internal.greyrock.io`, but the router's DNS record
   is `office-rb5009.internal.greyrock.io` → 10.1.0.1 and `www-ssl`
   answers on 10.1.0.1 / 10.1.10.1 / 10.1.20.1 — so every access threw
   a name mismatch.
3. **Root was RSA-2048** for a 10-year anchor — on the light side.

## What (new hierarchy)

All EC. Root/intermediate P-384, leaves P-256. `key-size` is the param
that selects the curve (`secp384r1` / `prime256v1`); there is no
`key-type` param on `add` (it's a read-only print field).

| Cert | Type | Usage | Validity | Notes |
|------|------|-------|----------|-------|
| **Grey Rock Root CA** | EC secp384r1 | key-cert-sign,crl-sign | 10 yr | self-signed, `trusted=yes` |
| **Grey Rock Intermediate CA** | EC secp384r1 | key-cert-sign,crl-sign | 5 yr | signed by root |
| **office-rb5009** (leaf) | EC prime256v1 | digital-signature,key-encipherment,tls-server | 2 yr | signed by intermediate; **not** a CA |

Router leaf SANs: `DNS:office-rb5009.internal.greyrock.io`,
`IP:10.1.0.1`, `IP:10.1.10.1`, `IP:10.1.20.1`.

Fingerprints (SHA-256), for the record (certs are not in `/export`):
- Root CA `daf1ac1c520531c553535898691f025b87d98c013e78d05893c292a7368ddfe9`
  (skid `C0E407CC74414C828E4E2CAA22294309E07A82C2`)
- Intermediate `07c2b2b759ba54b942a5747d57048e794113ac09129e830d39ba5315a556bf30`
  (skid `CD95A5DA5778012574CEBC7DF634749D0BCC9ED3`)
- office-rb5009 leaf `898e9f8693298d968f3dd89558ff58d5cedadfc3d7188f2f9f7d052b2226c0c1`

## Services

`/ip service` `www-ssl` and `api-ssl` re-pointed from `Grey Rock Router`
to `office-rb5009`. (This is the only cert-related change visible in
`running.txt`.)

## Distribution (the "make it trusted everywhere" step)

Exported the **root** public cert (PEM, no key) via
`/certificate export-certificate "Grey Rock Root CA" type=pem` → pull
from Winbox Files. Import `Grey Rock Root CA` into every client trust
store (macOS keychain / iOS profile / browsers). Trust flows from the
root, so only the root needs importing. The router serves leaf +
intermediate so clients can build the chain.

## Repeatable recipe — signing an appliance leaf

For a device `<host>` at IP `<ip>` (camera, Unleashed, etc.):

```
/certificate add name="<host>" common-name="<host>.internal.greyrock.io" \
    subject-alt-name="DNS:<host>.internal.greyrock.io,IP:<ip>" \
    key-size=prime256v1 key-usage=digital-signature,key-encipherment,tls-server days-valid=730
/certificate sign "<host>" ca="Grey Rock Intermediate CA"
/certificate export-certificate "<host>" type=pkcs12 export-passphrase=<pass>
```

The PKCS#12 export carries the leaf + its private key (passphrase-
protected) to install on the appliance; also give the appliance the
intermediate so it serves a full chain. Keep leaves off `key-cert-sign`.

## Repo / secrets

- Only the two `certificate=` refs changed in `running.txt`; snapshot
  `snapshots/2026-07-22-post-internal-ca-rebuild.txt`.
- Private keys never leave the router and are not in `/export`; nothing
  secret is committed.
