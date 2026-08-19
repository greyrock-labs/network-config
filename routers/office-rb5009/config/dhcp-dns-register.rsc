# dhcp-dns-register — RouterOS DHCP lease-script for office-rb5009
#
# Auto-registers dynamic DHCP leases into /ip dns static under
# internal.greyrock.io.
#   - Only acts on initial BIND, never on renew. Renews are silent.
#   - Skips fixed reservations (dynamic=no) so manual DNS records are
#     never touched.
#   - Tags its entries comment=dhcp-dns and only ever manages those.
#   - Removes its own entry on lease expiry (leaseBound=0 path).
#   - NEVER removes a static without comment=dhcp-dns. The script
#     touches only entries with comment=dhcp-dns, period.
#
# LOAD: paste this whole body into the Lease Script box
#   (Winbox/WebFig: IP > DHCP Server > <server> > Lease Script)
#   on dhcp-vlan1, dhcp-vlan10, dhcp-vlan20 — NOT guest.
#   Do NOT set it via CLI `set lease-script="..."` — the embedded " and $
#   need escaping and $ substitutes at set-time. Use the GUI box.
#
# TEST: attach to dhcp-vlan10 first. Bounce one dynamic device, confirm a
#   <hostname>.internal.greyrock.io record appears with comment=dhcp-dns
#   and disappears on lease expiry. Force a second device to the same
#   hostname to watch the -<macsuffix> variant appear. Then roll to the
#   other two servers.
#
# RENEW HANDLING: RouterOS fires the lease-script on T1/T2 renews with
# $leaseBound=1 but the lease already exists in the table. The original
# script treated every leaseBound=1 as a fresh bind and re-ran the
# removal/insert dance, which on a fixed-reservation box could clobber
# state. The new script distinguishes initial bind from renew by
# checking whether the script already owns a record for this IP; if it
# does, treat the event as a renew and do nothing.

:local zone "internal.greyrock.io"
:local tag "dhcp-dns"
:local ip $leaseActIP
:local mac $leaseActMAC

:if ($leaseBound = "1") do={
  # Skip if this IP has a fixed reservation — the operator manages DNS for it.
  :if ([:len [/ip dhcp-server lease find where address=$ip dynamic=no]] = 0) do={
    # If we already own a record for this IP, this is a renew — do nothing.
    :if ([:len [/ip dns static find where comment=$tag address=$ip]] > 0) do={
      :return
    }
    :local hn $"lease-hostname"
    :if ([:len $hn] = 0) do={ :set hn "host" }
    :local clean ($hn . "." . $zone)
    :local sfx ([:pick $mac 9 11] . [:pick $mac 12 14] . [:pick $mac 15 17])
    :local suffixed ($hn . "-" . $sfx . "." . $zone)
    # Belt and suspenders: only ever touch entries with our tag.
    :foreach r in=[/ip dns static find where comment=$tag address=$ip] do={ /ip dns static remove $r }
    :if ([:len [/ip dns static find where comment=$tag name=$clean]] = 0) do={
      /ip dns static add name=$clean address=$ip comment=$tag ttl=5m
    } else={
      :foreach r in=[/ip dns static find where comment=$tag name=$suffixed] do={ /ip dns static remove $r }
      /ip dns static add name=$suffixed address=$ip comment=$tag ttl=5m
    }
  }
} else={
  # Lease expired — remove our own record only. Never')
  :foreach r in=[/ip dns static find where comment=$tag address=$ip] do={ /ip dns static remove $r }
}
