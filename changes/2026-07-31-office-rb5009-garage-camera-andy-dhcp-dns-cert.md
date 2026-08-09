# office-rb5009: garage-camera-andy — DHCP+DNS reservation and TLS cert

2026-07-31

## Why

Todd installed a second Hikviscamera in the garage (Andy's side). Same workflow as
garage-camera-todd: DHCP reservation, DNS A record, and a TLS cert
signed off the root (Hikvision serves leaf-only, can't present the
intermediate).

## What changed (on office-rb5009)

**DHCP reservation** (VLAN 10):
```
/ip dhcp-server lease
add address=10.1.10.68 mac-address=74:3F:C2:E7:EB:73 server=dhcp-vlan10 comment="Garage Camera - Andy"
remove [find where address=10.1.10.68 dynamic=yes]
```

**DNS A record:**
```
/ip dns static
add address=10.1.10.68 name=garage-camera-andy.internal.greyrock.io type=A
```

**TLS cert** (signed off root, EC P-256, 730 days):
```
/certificate add name="garage-camera-andy" common-name="garage-camera-andy.internal.greyrock.io" \
    subject-alt-name="DNS:garage-camera-andy.internal.greyrock.io,IP:10.1.10.68" \
    key-size=prime256v1 key-usage=digital-signature,key-encipherment,tls-server days-valid=730
/certificate sign "garage-camera-andy" ca="Grey Rock Root CA"
```

Cert details:
- Serial: `416AD26D799A7A22`
- SHA-256 fingerprint: `5b309947e2fbfbd6b7c248a2f16e1c18300466f298c4e9f39bbed2a66758dcf2`
- Issued: 2026-07-31, Expires: 2028-07-30
- Key: EC P-256, signed off root, leaf-only chain

## Verification

- Static lease present, status `waiting` (binds on next DHCP request).
- DNS A record: `garage-camera-andy.internal.greyrock.io A 10.1.10.68`.
- TLS verified: `Verify return code: 0 (ok)` against the root CA.

## Repo

- `routers/office-rb5009/config/running.txt` — DHCP lease + DNS A record
- `routers/office-rb5009/issued-certs.md` — cert row + fingerprint