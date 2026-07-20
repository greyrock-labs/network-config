# dhcp-dns-register — RouterOS DHCP lease-script for office-rb5009
#
# Auto-registers dynamic DHCP leases into /ip dns static under
# internal.greyrock.io.
#   - Clean hostname by default; appends the last 3 MAC octets ONLY when
#     another device already holds that name (collision).
#   - Skips fixed reservations (dynamic=no) so manual DNS records are
#     never touched.
#   - Tags its entries comment=dhcp-dns and only ever manages those.
#   - Removes the entry on lease expiry.
#
# LOAD: paste this whole body into the Lease Script box
#   (Winbox/WebFig: IP > DHCP Server > <server> > Lease Script)
#   on dhcp-vlan1, dhcp-vlan10, dhcp-vlan20 — NOT guest.
#   Do NOT set it via CLI `set lease-script="..."` — the embedded " and $
#   need escaping and $ substitutes at set-time. Use the GUI box.
#
# TEST: attach to dhcp-vlan10 first. Bounce one dynamic device, confirm a
#   <hostname>.internal.greyrock.io record appears with comment=dhcp-dns
#   and disappears on lease expiry. Then force a second device to the same
#   hostname to watch the -<macsuffix> variant appear. Then roll to the
#   other two servers.

:local zone "internal.greyrock.io"
:local tag "dhcp-dns"
:local ip $leaseActIP
:local mac $leaseActMAC

:if ($leaseBound = "1") do={
  :if ([:len [/ip dhcp-server lease find where address=$ip dynamic=no]] = 0) do={
    :local hn $"lease-hostname"
    :if ([:len $hn] = 0) do={ :set hn "host" }
    :local clean ($hn . "." . $zone)
    :local sfx ([:pick $mac 9 11] . [:pick $mac 12 14] . [:pick $mac 15 17])
    :local suffixed ($hn . "-" . $sfx . "." . $zone)
    :foreach r in=[/ip dns static find where comment=$tag address=$ip] do={ /ip dns static remove $r }
    :if ([:len [/ip dns static find where comment=$tag name=$clean]] = 0) do={
      /ip dns static add name=$clean address=$ip comment=$tag ttl=5m
    } else={
      :foreach r in=[/ip dns static find where comment=$tag name=$suffixed] do={ /ip dns static remove $r }
      /ip dns static add name=$suffixed address=$ip comment=$tag ttl=5m
    }
  }
} else={
  :foreach r in=[/ip dns static find where comment=$tag address=$ip] do={ /ip dns static remove $r }
}
