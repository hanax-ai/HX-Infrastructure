#!/usr/bin/env bash
set -euo pipefail

FQDN_DEFAULT="$(hostname -f 2>/dev/null || true)"
: "${HX_FQDN:=${FQDN_DEFAULT:-}}"
: "${HX_IP:=}"
: "${HX_GW:=192.168.10.1}"
: "${HX_DC:=192.168.10.2}"
: "${HX_REALM:=DEV-TEST.HANA-X.AI}"
: "${HX_DOMAIN:=dev-test.hana-x.ai}"
: "${HX_PERMIT_GROUPS:=Domain Admins,DevOps Users}"

fail(){ echo "ERROR: $*" >&2; exit 1; }
detect_if(){ ip -o -4 route show default 2>/dev/null | awk '{print $5; exit}'; }

IFACE="${IFACE:-$(detect_if)}"
[ -n "$IFACE" ] || fail "No NIC"
[ -n "$HX_IP" ] || fail "Need HX_IP"

sudo ufw disable || true
sudo systemctl stop firewalld 2>/dev/null || true
sudo systemctl disable firewalld 2>/dev/null || true

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  net-tools dnsutils realmd sssd sssd-tools krb5-user samba-common-bin adcli \
  ldap-utils oddjob oddjob-mkhomedir packagekit

sudo resolvectl dns "$IFACE" "$HX_DC"
sudo resolvectl domain "$IFACE" "$HX_DOMAIN"

sudo tee /etc/netplan/01-hx.yaml >/dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      addresses: [${HX_IP}/24]
      routes:
        - to: default
          via: ${HX_GW}
      nameservers:
        search: [${HX_DOMAIN}]
        addresses: [${HX_DC}]
EOF
sudo chmod 600 /etc/netplan/01-hx.yaml
sudo netplan apply

echo "=== realm join ==="
kinit "administrator@${HX_REALM}"
realm discover "${HX_REALM}" >/dev/null
sudo realm join "${HX_REALM}" -U Administrator || echo "Already joined?"

# Ensure sssd config exists (realmd may create it; if not, we do)
if [ ! -s /etc/sssd/sssd.conf ]; then
  sudo tee /etc/sssd/sssd.conf >/dev/null <<EOF
[sssd]
services = nss, pam
domains = ${HX_DOMAIN}

[domain/${HX_DOMAIN}]
id_provider = ad
ad_domain = ${HX_DOMAIN}
krb5_realm = ${HX_REALM}
cache_credentials = True
access_provider = ad
fallback_homedir = /home/%u
default_shell = /bin/bash
EOF
fi
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd

# NSS/PAM glue
sudo sed -i 's/^passwd:.*/passwd:         files systemd sss/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*/group:          files sss/' /etc/nsswitch.conf
sudo sed -i 's/^shadow:.*/shadow:         files sss/' /etc/nsswitch.conf
sudo systemctl enable --now oddjobd
grep -q pam_mkhomedir.so /etc/pam.d/common-session || \
  echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0022" | sudo tee -a /etc/pam.d/common-session >/dev/null

# Allow specified AD groups
IFS=',' read -ra GROUPS_ARR <<< "$HX_PERMIT_GROUPS"
for g in "${GROUPS_ARR[@]}"; do sudo realm permit -g "$(echo "$g" | xargs)"; done

# Sanity
id "administrator@${HX_DOMAIN}" || true
getent passwd "administrator@${HX_DOMAIN}" || true
