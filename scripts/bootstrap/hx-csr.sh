#!/usr/bin/env bash
set -euo pipefail
# self-elevate
[ "${EUID:-$(id -u)}" -eq 0 ] || exec sudo -E bash "$0" "$@"
umask 077

: "${HX_FQDN:?Need HX_FQDN}"
: "${HX_ORG:=Hana-X AI}"
: "${HX_OU:=HX Infrastructure}"
: "${HX_CITY:=Frisco}"
: "${HX_STATE:=Texas}"
: "${HX_COUNTRY:=US}"

OUT="/etc/ssl/hx"
install -d -m 700 "$OUT"
cd "$OUT"

SHORT="$(hostname -s)"
KEY="${SHORT}.key"
CSR="${SHORT}.csr"

if [ -f "$KEY" ]; then
  echo "Reusing existing key $KEY; generating NEW CSR only"
  openssl req -new -key "$KEY" -out "$CSR" \
    -subj "/C=${HX_COUNTRY}/ST=${HX_STATE}/L=${HX_CITY}/O=${HX_ORG}/OU=${HX_OU}/CN=${HX_FQDN}"
else
  echo "Generating NEW key + CSR (EC P-384)"
  openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-384 -nodes \
    -keyout "$KEY" -out "$CSR" \
    -subj "/C=${HX_COUNTRY}/ST=${HX_STATE}/L=${HX_CITY}/O=${HX_ORG}/OU=${HX_OU}/CN=${HX_FQDN}"
fi
chmod 600 "$KEY" "$CSR"

# Stage CSR for user transfer
CALLER="${SUDO_USER:-$USER}"
STAGE="/home/${CALLER}/certs_in"
install -d -m 700 -o "$CALLER" -g "$CALLER" "$STAGE"
install -m 600 -o "$CALLER" -g "$CALLER" "$CSR" "${STAGE}/${CSR}"
echo "CSR staged at ${STAGE}/${CSR}"
