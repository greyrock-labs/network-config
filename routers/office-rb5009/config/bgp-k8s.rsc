# bgp-k8s — RouterOS 7 BGP config for office-rb5009 <-> k8s cluster
#
# Translated from the UDM/FRR config. Peers with the cluster to LEARN its
# LoadBalancer routes (10.1.25.0/24 range; k8s API/ingress VIP 10.1.25.2).
#
# Local AS 64513 (router) <-> remote AS 64514 (cluster), eBGP.
# Peer: 10.1.20.10 (kerfuffle, a k8s node on VLAN 20). Add more cluster
# nodes by copying the connection with a new name + remote.address.
#
# Mapping notes from the FRR source:
#   next-hop-self            -> output.nexthop-choice=force-self
#   ipv4 unicast             -> address-families=ip
#   soft-reconfiguration in  -> no RO7 equivalent (RO7 retains received
#                               routes natively); omitted
#   no bgp ebgp-requires-policy -> RO7 doesn't enforce RFC 8212; omitted
#   (no `network` statements -> router only receives, advertises nothing)
#
# Enabled — it just sits idle until the peer is reachable, no harm. For the
# session to actually establish: (1) box live with 10.1.20.10 reachable,
# (2) vlan20 in the LAN interface-list (done in the firewall chunk) or an
# input rule accepting TCP 179 from 10.1.20.10 — otherwise the defconf
# "drop not from LAN" input rule drops it.
# NOTE: RouterOS 7 BGP param syntax is finicky — verify against the device
#       (?) before relying on it; can't be tested until the cluster peers.

# v7 BGP structure: the LOCAL AS lives on the /routing/bgp/template (not the
# connection); the connection references it via templates=default. That
# template reference is required — omitting it makes the CLI prompt for
# "instance". No as=, router-id=, or address-families= on the connection:
# AS + address-family (afi) belong to the template, router-id is auto.
# Router only receives (no output.network), so eBGP next-hop handling is moot.
# RouterOS 7.20+ REQUIRES an explicitly-created BGP instance (no auto-default).
# The local AS lives on the instance; the connection references it via
# instance=<name>. No templates, no as=/address-families=/router-id= on the
# connection. (Optional: pin router-id on the instance to match the old FRR
# `bgp router-id 10.1.0.1` — /routing/bgp/instance set greyrock router-id=10.1.0.1)
/routing/bgp/instance add name=greyrock as=64513
/routing/bgp/connection add name=k8s-kerfuffle instance=greyrock remote.address=10.1.20.10 remote.as=64514 local.role=ebgp local.address=10.1.20.1 connect=yes listen=yes
