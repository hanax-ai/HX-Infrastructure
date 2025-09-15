#!/usr/bin/env bash
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || exec sudo -E bash "$0" "$@"
umask 077

FQDN="${HX_FQDN:-$(hostname -f)}"
SHORT="$(hostname -s)"
SSL_DIR="/etc/ssl/hx"
NGX_DIR="/etc/nginx/tls"
STAGE="${HOME}/certs_in"
SITE="/etc/nginx/sites-available/${SHORT}.conf"

apt-get update -y && apt-get install -y nginx
install -d -m 755 /etc/nginx/sites-available /etc/nginx/sites-enabled
install -d -m 700 -o root -g root "$SSL_DIR" "$NGX_DIR"

# Require artifacts
[ -f "$STAGE/${SHORT}.crt" ] || { 
    echo "ERROR: Missing server certificate file at: $STAGE/${SHORT}.crt"
    echo "       The signed certificate for '$SHORT' must be placed in the staging directory."
    echo "       To remediate: Obtain the signed certificate from your CA and place it at the path above."
    exit 1
}
[ -f "$STAGE/ca.crt" ] || { 
    echo "ERROR: Missing CA certificate file at: $STAGE/ca.crt"
    echo "       The CA root certificate is required for the certificate chain."
    echo "       To remediate: Copy the CA certificate to $STAGE/ca.crt"
    exit 1
}
[ -f "$SSL_DIR/${SHORT}.key" ] || { 
    echo "ERROR: Missing private key file at: $SSL_DIR/${SHORT}.key"
    echo "       The private key should have been generated for server '$SHORT'."
    echo "       To remediate: Run the CSR generation script 'hx-csr.sh' first to create the key."
    exit 1
}

# Install to secure store
install -m 600 "$STAGE/${SHORT}.crt" "$SSL_DIR/${SHORT}.crt"
install -m 600 "$STAGE/ca.crt"       "$SSL_DIR/ca.crt"
chmod 600 "$SSL_DIR"/*

# Copy for nginx
install -m 600 "$SSL_DIR/${SHORT}.crt" "$NGX_DIR/${SHORT}.crt"
install -m 600 "$SSL_DIR/ca.crt"       "$NGX_DIR/ca.crt"
install -m 600 "$SSL_DIR/${SHORT}.key" "$NGX_DIR/${SHORT}.key"

# --- Key/Cert public key hash guard (prevents mismatches) ---
CERT_FP="$(openssl x509 -in "$NGX_DIR/${SHORT}.crt" -noout -pubkey | openssl sha256 | awk '{print $2}')"
KEY_FP="$(openssl pkey -in "$NGX_DIR/${SHORT}.key" -pubout | openssl sha256 | awk '{print $2}')"
if [ "$CERT_FP" != "$KEY_FP" ]; then
  echo "ERROR: cert/key mismatch!"
  echo "  cert pubkey sha256: $CERT_FP"
  echo "  key  pubkey sha256: $KEY_FP"
  echo "Refusing to reload nginx. Re-sign the CSR that matches the on-host key."
  exit 1
fi

# Site config
cat > "$SITE" <<NGINX
server {
    listen 443 ssl;
    server_name ${FQDN};

    ssl_certificate           ${NGX_DIR}/${SHORT}.crt;
    ssl_certificate_key       ${NGX_DIR}/${SHORT}.key;
    ssl_trusted_certificate   ${NGX_DIR}/ca.crt;

    location / {
        root /var/www/html;
        index index.html;
    }
}
NGINX

install -d -m 755 /var/www/html
echo "<h1>HX ${SHORT^^} — Secure</h1>" > /var/www/html/index.html
chmod 644 /var/www/html/index.html

ln -sfn "$SITE" "/etc/nginx/sites-enabled/${SHORT}.conf"
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable --now nginx
systemctl restart nginx
echo "DONE: ${FQDN} is live on 443."
