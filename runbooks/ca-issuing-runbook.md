# Runbook — issuing an internal cert from the Grey Rock CA

The CA lives on **office-rb5009**. Hierarchy (all EC):

```
Grey Rock Root CA (secp384r1, self-signed, trusted)
└─ Grey Rock Intermediate CA (secp384r1)   ← everything gets signed off this
   └─ <device leaf> (prime256v1)
```

Use it for internal devices that can't do ACME (cameras, Ruckus
Unleashed, appliance mgmt UIs). **Not** k8s — cluster TLS is handled
in-cluster. Record every issued cert in `../routers/office-rb5009/issued-certs.md`.

---

## Method A — router generates the key (default, simplest)

Good for appliances that just want a cert + key uploaded.

### 1. Create + sign the leaf (on office-rb5009)

Replace `<name>` (RouterOS object name), `<host>` (short DNS name), `<ip>`:

```
/certificate add name="<name>" common-name="<host>.internal.greyrock.io" \
    subject-alt-name="DNS:<host>.internal.greyrock.io,IP:<ip>" \
    key-size=prime256v1 key-usage=digital-signature,key-encipherment,tls-server days-valid=730
/certificate sign "<name>" ca="Grey Rock Intermediate CA"
```

Rules that matter:
- `key-size` picks the algorithm/curve — `prime256v1` = EC P-256. There is
  **no** `key-type` param on `add` (it's read-only in print output).
- Leaves get `tls-server` only — **never** `key-cert-sign`/`crl-sign` (that
  would make the leaf a CA).
- SANs are what browsers match (CN is ignored). Include the DNS name and,
  if you'll hit it by IP, an `IP:` SAN. IP SANs **are** trusted for a
  private CA.
- `days-valid` **≤ 825**. Safari hard-caps private-CA chains at ~825 days;
  the public 398-day limit does not apply to our own root.

### 2. Verify before exporting

```
/certificate print detail where name="<name>"
```
Want: flags `KI` (**no** `A`), `key-usage=…,tls-server` (no cert-sign),
`ca=Grey Rock Intermediate CA`, `key-size=prime256v1`, and the right SANs.

### 3. Export cert + key

Use the **Winbox GUI dialog**, not the CLI — the Winbox terminal eats the
`export-passphrase=` line (and `export-certificate` prints nothing on
success, so it looks like it failed even when it worked).

> System → Certificates → select `<name>` → **Export** → Type `PEM`,
> set an **Export Passphrase** → Export

Gives `<name>.crt` + `<name>.key` (key encrypted) in Files. Also export the
intermediate once (public cert, no key — no passphrase):

```
/certificate export-certificate "Grey Rock Intermediate CA" type=pem
```

Pull the files from Winbox → Files.

### 4. Prep the files (workstation)

```
# strip the passphrase (openssl pkey handles EC + either PEM format)
openssl pkey -in "<name>.key" -out <host>.key

# build the chain: leaf FIRST, then intermediate, NOT the root
cat "<name>.crt" "Grey Rock Intermediate CA.crt" > <host>-fullchain.crt
```

Sanity-check the bundle has two certs cleanly separated:
```
grep -c "BEGIN CERTIFICATE" <host>-fullchain.crt   # -> 2
```
(A missing trailing newline in the leaf file glues the two blocks together
and only the first parses.)

### 5. Install on the device

Upload **`<host>-fullchain.crt`** as the certificate and **`<host>.key`** as
the key. The device must present **leaf + intermediate** or clients get an
incomplete-chain error — a device field labeled "additional/trusted CA
certificates" is a *client-trust* list, **not** where the served chain
goes; put the intermediate in the cert bundle instead.

Delete the un-passphrased `<host>.key` from the workstation once installed.

### 6. Verify

```
# should show TWO blocks: leaf issued by Intermediate, Intermediate issued by Root
echo | openssl s_client -connect <host>.internal.greyrock.io:443 -showcerts 2>/dev/null | grep -E "s:|i:"

# full-path check (openssl ignores the macOS keychain, so point it at the root)
echo | openssl s_client -connect <host>.internal.greyrock.io:443 -CAfile "Grey Rock Root CA.crt" 2>/dev/null | grep "Verify"
#   -> Verify return code: 0 (ok)
```
Browser test: the page is Secure **only on clients that trust the root**
(see Distribution). `20 (unable to get local issuer)` from plain `s_client`
is benign — it just means openssl doesn't have the root; the browser does.

### 7. Record it

Add a row to `../routers/office-rb5009/issued-certs.md` (name, CN, SANs, key, issued/expires, serial,
device).

---

## Method B — device generates the key (CSR), sign off-box

Use when the private key must never leave the device.

**RouterOS cannot sign an external CSR** — it only signs templates it
generated itself. So the router is *not* the signer here. Instead:

1. Generate the CSR on the device (with its SANs).
2. Export the **intermediate** cert **and key** from the router once
   (Winbox export, Type `PKCS12`, with a passphrase) onto a workstation.
3. Sign the CSR there with openssl — remember `openssl x509 -req` drops the
   CSR's SANs unless you pass `-copy_extensions copy` (OpenSSL 3.x) or an
   `-extfile`.
4. Return leaf + intermediate to the device (as in Method A step 5).

Trade-off: the intermediate's private key now also lives on that
workstation. Fine for homelab; if CSR-signing becomes routine, that
workstation (XCA / an openssl CA dir) is really the better CA home.

---

## Distribution (one-time per client)

Everything above only shows "valid" on clients that trust the root. Export
the **root** (public only) and import it into each client's trust store
(macOS/iOS/browsers), set to Always Trust. Root only — never distribute the
intermediate or a leaf.

```
/certificate export-certificate "Grey Rock Root CA" type=pem
```

---

## Renewal

Leaves expire per their `days-valid`. Re-run Method A with the same
name/CN/SANs, re-export, re-install, update `../routers/office-rb5009/issued-certs.md`.
