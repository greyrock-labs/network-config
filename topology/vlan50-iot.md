# VLAN 50 (IoT)

The IoT segment: how it is addressed, what policy applies, and how each
device in the fleet is configured for it.

## Purpose

A segment for devices that misbehave on the trusted LAN. The first
tenant is the SolarEdge inverter, which re-answers the mDNS
service-discovery meta-query every ~7 seconds with a TTL of 60 instead
of 4500. That drags shared cache entries down and makes browsing
clients on VLAN 10 expire their whole service list on a ~179-second
cycle. Moving it to its own segment that the mDNS repeater does not
touch contains the pollution.

## Scope

This is a quarantine segment for individual offenders, not a general
IoT segment. A device earns a place here by demonstrating a specific
problem. The IoT WiFi SSID lives on VLAN 10 and stays there; smart-home
gear in general has not misbehaved the way the inverter did. That is why
VLAN 50 is wired-only and is not tagged on any AP port.

## Addressing

| Field | Value |
| --- | --- |
| VLAN ID | 50 |
| Name | IoT |
| Subnet | 10.1.50.0/24 |
| Gateway | 10.1.50.1 (office-rb5009, `vlan50`) |
| DHCP pool | 10.1.50.20 – 10.1.50.254 |
| Lease time | 8h |
| DHCP DNS | 10.1.30.20 (ctrld container) |
| DHCP domain | internal.greyrock.io |
| DHCP NTP | 10.1.20.16–19 |
| IPv6 | none — IPv4 only |

IPv4 only: no ULA address, no prefix carved from the Spectrum PD, and
no IPv6 address on the `vlan50` interface, so there is no prefix to
advertise on the segment.

## Policy

- **Routed like VLAN 10 and 20.** No isolation rules.
- **Internet** works through the existing defconf masquerade
  (`chain=srcnat action=masquerade out-interface-list=WAN`). No NAT
  change.
- **`LAN` interface-list membership is required.** The input chain ends
  in `drop all not coming from LAN`, so without it the router will not
  answer DHCP or DNS on the segment.
- **`DNS-FORCE` membership** dst-nats port 53 to the ctrld container,
  which covers devices that ship hardcoded upstream resolvers.
- **Excluded from `mdns-repeat-ifaces`.** This is the point of the
  segment. The repeater serves `vlan10,vlan20,bridge`.
- Guest isolation already covers this segment: the rule dropping
  VLAN 4000 to the `internal` address-list matches `10.1.0.0/16`, which
  contains 10.1.50.0/24.

## Reservations and DNS

| Device | MAC | Address | DNS name |
| --- | --- | --- | --- |
| SolarEdge inverter | 84:D6:C5:11:38:8B | 10.1.50.10 | solaredge.internal.greyrock.io |

The reservation carries a hand-maintained `/ip dns static` record.
`dhcp-vlan50` runs without the `dhcp-dns-register` lease-script — the
script exists to name a crowd, and one device with a fixed reservation
does not need it. Attach it if the segment grows.

## Device configuration

### Router — office-rb5009

```
/interface vlan add interface=bridge name=vlan50 vlan-id=50
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 vlan-ids=50
/ip address add address=10.1.50.1/24 interface=vlan50 network=10.1.50.0
/interface list member add interface=vlan50 list=LAN
/interface list member add interface=vlan50 list=DNS-FORCE
/ip pool add name=vlan50-iot ranges=10.1.50.20-10.1.50.254
/ip dhcp-server add address-pool=vlan50-iot interface=vlan50 lease-time=8h name=dhcp-vlan50
/ip dhcp-server network add address=10.1.50.0/24 dns-server=10.1.30.20 domain=internal.greyrock.io \
    gateway=10.1.50.1 ntp-server=10.1.20.16,10.1.20.17,10.1.20.18,10.1.20.19
/ip dhcp-server lease add address=10.1.50.10 comment="SolarEdge Inverter" \
    mac-address=84:D6:C5:11:38:8B server=dhcp-vlan50
/ip dns static add address=10.1.50.10 name=solaredge.internal.greyrock.io type=A
```

The router bridge is a tagged member because its L3 `vlan50` interface
rides the bridge. `sfp-sfpplus1` is the spine trunk to office-crs309.

### Spine — CRS309s

Identical treatment to VLANs 10/20/4000: tagged on used SFP+ ports,
no bridge membership.

```
# office-crs309, game-room-crs309 (ports 1-4 used)
/interface bridge vlan add bridge=bridge tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 vlan-ids=50

# garage-crs309 (ports 1-3 used)
/interface bridge vlan add bridge=bridge tagged=sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3 vlan-ids=50
```

### Access — ICX

VLAN 50 is tagged on the uplink only. AP ports are not members: the
first tenant is wired, and no IoT SSID exists. Adding one later means
tagging VLAN 50 on the AP ports at that time.

| Switch | Uplink | VLAN 50 members |
| --- | --- | --- |
| office-icx-8200 | 1/2/2 | tagged 1/2/2 |
| office-icx-7150 | 1/3/2 | tagged 1/3/2 |
| game-room-icx-8200 | 1/2/2 | tagged 1/2/2 |
| game-room-icx-7150 | 1/3/2 | tagged 1/3/2, untagged 1/1/1 (SolarEdge) |
| garage-icx-8200 | 1/2/2 | tagged 1/2/2 |
| garage-icx-7150 | 1/3/2 | tagged 1/3/2 |

```
configure terminal
vlan 50 name IoT by port
 tagged ethe <uplink>
end
write memory
```

VLAN 50 carries no `multicast`/`multicast6` configuration, matching
VLANs 20 and 4000 on this fleet: no querier, unregistered groups
flood. The segment exists to keep mDNS off VLAN 10, not to snoop it.

### Device move — game-room-icx-7150 port 1/1/1

FastIron allows a port to be untagged in one VLAN only, so the port
leaves VLAN 10 before it joins VLAN 50. VLAN 10 holds
`untagged ethe 1/1/1 to 1/1/2`; port 1/1/2 (Zigbee) stays.

```
configure terminal
vlan 10
 no untagged ethe 1/1/1
vlan 50
 untagged ethe 1/1/1
end
write memory
```

Port-level settings on 1/1/1 (`port-name SolarEdge`, `stp-bpdu-guard`,
`broadcast limit 500`) are VLAN-independent and untouched.

## Apply order

Build the segment from the router outward so it exists before the
device lands on it. Steps 1–4 add trunk memberships and interrupt no
existing traffic; step 5 is the only one a device notices.

1. **office-crs309 pre-check** — `/interface bridge vlan print`. VLANs
   10/20/4000 must read `tagged=sfp-sfpplus1..4` with no `bridge`
   member. Put them back to that if they differ.
2. **office-rb5009** — the router block above.
3. **CRS309s** — office, game-room, garage.
4. **Five ICX** — office-8200, office-7150, game-room-8200,
   garage-8200, garage-7150: uplink tag only.
5. **game-room-icx-7150** — uplink tag, then the 1/1/1 move. The
   inverter drops for a few seconds and returns on 10.1.50.10.

## Verification

- `/ip dhcp-server lease print where server=dhcp-vlan50` — inverter
  bound to 10.1.50.10.
- `/ping 10.1.50.10` from office-rb5009.
- `/interface bridge vlan print` on each CRS309 — VLAN 50 row present
  with the expected `CURRENT-TAGGED` ports.
- `show vlan 50` on each ICX — expected tagged/untagged members.
- ctrld logs show queries sourced from 10.1.50.10.
- `/ipv6 neighbor print where interface=vlan50` and
  `/ipv6 address print where interface=vlan50` — both empty, i.e. the
  segment is IPv4-only in practice and not just by omission. If the
  inverter picks up a link-local-only address that is expected; a
  global address is not.
- mDNS browse from a VLAN 10 client (`dns-sd -B
  _services._dns-sd._udp local.`, wrapped in `caffeinate -i`): the
  ~179-second mass-expiry cycle is gone. Baseline for comparison is
  ~700 adds and ~700 removals per hour.

## Follow-up

Home Assistant polling the inverter locally by IP points at its old
VLAN 10 address and needs re-pointing to 10.1.50.10 or
`solaredge.internal.greyrock.io`. A cloud-API integration needs
nothing.
