# office-rb5009: issue cert for garage-camera-todd (Hikvision)

2026-07-31

## Why

Todd installed a new Hikvision camera in the garage at 10.1.10.66.
DHCP reservation and DNS were done first (separate change
`2026-07-31-office-rb5009-garage-camera-todd-dhcp-dns.md`). This change
issues the TLS cert so the camera's HTTPS web UI is trusted on clients
that have the Grey Rock Root CA imported.

## What changed (on office-rb5009)

Created and signed a leaf cert directly off the **Root CA** (not the
intermediate), because Hikvision serves only the leaf cert and cannot
present the intermediate — same treatment as `garage-camera-side-yard`
and `kvm-homeassistant`.

```
/certificate add name="garage-camera-todd" common-name="garage-camera-todd.internal.greyrock.io" \
    subject-alt-name="DNS:garage-camera-todd.internal.greyrock.io,IP:10.1.10.66" \
    key-size=prime256v1 key-usage=digital-signature,key-encipherment,tls-server days-valid=730
/certificate sign "garage-camera-todd" ca="Grey Rock Root CA"
```

Cert details:
- Serial: `53973909E3635469`
- SHA-256 fingerprint: `ce0b613fbfde0a36bc3f7f3cf9569eafe971350ff554555440c2846467fd0ca4`
- Issued: 2026-07-31, Expires: 2028-07-30
- Key: EC P-256, signed off root, leaf-only chain

Exported cert + key via Winbox (PEM, passphrase-protected), stripped
the passphrase with `openssl pkey`, uploaded to the Hikvision web UI.

## Also fixed

Recorded the workstation path for the exported root CA cert in
`runbooks/ca-issuing-runbook.md`:
`~/Documents/Grey Rock/cert_export_Grey Rock Root CA.crt`

This was missing from the docs — needed for `-CAfile` in openssl
verification commands.

## Repo

- `routers/office-rb5009/issued-certs.md` — added garage-camera-todd row + fingerprint
- `runbooks/ca-issuing-runbook.md` — added root CA CRT local path