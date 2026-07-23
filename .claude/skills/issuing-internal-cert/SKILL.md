---
name: issuing-internal-cert
description: Use when issuing, renewing, or installing an internal TLS certificate from the Grey Rock CA for a homelab device that can't do ACME — cameras, Ruckus Unleashed, appliance/mgmt web UIs. Covers the office-rb5009 RouterOS CA, leaf signing, chain building, incomplete-chain errors, private-CA trust, and IP SANs. NOT for k8s (cluster TLS is in-cluster).
---

# Issuing an internal cert from the Grey Rock CA

## Overview

The CA lives on **office-rb5009** (RouterOS). All EC:

```
Grey Rock Root CA (secp384r1, self-signed, trusted)
└─ Grey Rock Intermediate CA (secp384r1)   ← everything signs off this
   └─ <device leaf> (prime256v1)
```

For internal devices that can't do ACME. **Not** k8s (cluster TLS is
in-cluster). Every issued cert gets a row in
`routers/office-rb5009/issued-certs.md`.

**Full step-by-step procedure:** `runbooks/ca-issuing-runbook.md` — this
skill is the map + the traps; follow the runbook for exact commands.

**Exported CA files** (root + intermediate, public) live on the workstation
at `~/Documents/Grey Rock/` as `cert_export_*.crt`. Re-export from the router
after any CA rebuild so these stay current.

## Which method

| Situation | Method |
|-----------|--------|
| Appliance just needs cert + key uploaded (default) | **A** — router generates the key |
| Private key must never leave the device | **B** — device makes a CSR, sign off-box with openssl (RouterOS **cannot** sign an external CSR) |

## Device quirks

- **Reolink (PoE doorbell, cameras) — RSA only.** The HTTPS web service
  rejects EC certs (upload just says "failed"). Issue the leaf with
  `key-size=2048` (numeric = RSA; a curve name = EC). Upload under
  Settings → Network → Advanced → **HTTPS Settings**; the cert field wants
  the full chain (leaf + intermediate). Filenames containing the FQDN can
  break the upload — use plain `server.crt` / `server.key`.
- **RSA key encoding.** OpenSSL 3.x `openssl rsa` emits PKCS#8
  (`BEGIN PRIVATE KEY`) by default; add **`-traditional`** for the PKCS#1
  (`BEGIN RSA PRIVATE KEY`) form old appliances expect.
- **Hikvision — serves leaf-only; accepts EC.** Cert Management has two
  slots: *Server/Client Certificate* (the leaf it serves) and *CA
  Certificate*. The CA slot is a **client-trust store, not chain-serving** —
  importing the intermediate there does NOT add it to the served chain, and
  `s_client -showcerts` still shows one block → `21 unable to verify`. Fix:
  **sign the leaf directly off the root** (below).

- **Leaf-only devices → sign off the ROOT.** If a device serves only its leaf
  and can't present the intermediate, a leaf signed off the intermediate
  fails `21 unable to verify the first certificate` (clients trust the root,
  not the intermediate). Reissue with `ca="Grey Rock Root CA"` instead of the
  intermediate; the leaf-only chain then validates against the root. Verify
  the served issuer: `s_client -showcerts` → leaf `i:` line reads
  `CN=Grey Rock Root CA`. In this case `server.crt` is the **leaf alone** (no
  intermediate to bundle).

## Guardrails (the things that bite)

- **Leaves get `tls-server` only** — never `key-cert-sign`/`crl-sign` (that
  makes the leaf a CA). Verify: flags `KI` with **no** `A`.
- **`days-valid` ≤ 825.** Safari hard-caps private-CA chains at ~825 days.
  The public 398-day limit does not apply to our own root.
- **SANs are what browsers match; CN is ignored.** Include the DNS name and
  an `IP:` SAN if you'll hit it by IP — IP SANs *are* trusted for a private CA.
- **Serve leaf + intermediate**, not the root. A device field labeled
  "additional/trusted CA certificates" is a *client-trust* list, **not**
  where the served chain goes — put the intermediate in the cert bundle.
- **Chain order: leaf FIRST, then intermediate.** Verify the bundle:
  `grep -c "BEGIN CERTIFICATE" <host>-fullchain.crt` → must be `2`. A missing
  trailing newline in the leaf glues the blocks together and only the first parses.
- **Export via the Winbox GUI dialog, not CLI** — the Winbox terminal eats
  `export-passphrase=`, and `export-certificate` prints nothing on success.
- **Method B drops SANs** unless `openssl x509 -req -copy_extensions copy`
  (OpenSSL 3.x) or an `-extfile`.
- **Delete the un-passphrased `<host>.key`** from the workstation once installed.

## Verify it worked

```
# leaf issued by Intermediate, Intermediate issued by Root (two blocks)
echo | openssl s_client -connect <host>.internal.greyrock.io:443 -showcerts 2>/dev/null | grep -E "s:|i:"
# full-path check (openssl ignores the macOS keychain)
echo | openssl s_client -connect <host>.internal.greyrock.io:443 -CAfile "Grey Rock Root CA.crt" 2>/dev/null | grep "Verify"
#   -> Verify return code: 0 (ok)
```

`20 (unable to get local issuer)` from plain `s_client` is benign — openssl
lacks the root; the browser has it.

## Trust (one-time per client)

The page is Secure only on clients that trust the **root**. Export the root
(public only), import to each client's trust store set to Always Trust. Root
only — never distribute the intermediate or a leaf.

## After every issue/renew

Add/update the row in `routers/office-rb5009/issued-certs.md`
(name, CN, SANs, key, issued/expires, serial, device).
