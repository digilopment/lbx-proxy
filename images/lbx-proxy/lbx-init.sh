#!/bin/bash

set -e

# Cesta k JSON súboru s doménami
JSON_FILE="/config/domains.json"
NGINX_CONF_DIR="/etc/nginx/conf.d"
CHALLENGE_DIR="/var/www/certbot"

# Skontrolovať, či JSON súbor existuje
if [[ ! -f $JSON_FILE ]]; then
  echo "JSON file not found: $JSON_FILE"
  exit 1
fi

# Vymazať starý súbor default.conf
DEFAULT_CONF="${NGINX_CONF_DIR}/default.conf"
> "$DEFAULT_CONF"

# Parsovanie JSON a generovanie certifikátov pre každú doménu
jq -r '.domains | to_entries[] | "\(.key) \(.value)"' "$JSON_FILE" | while read -r domain ip_address; do

if [ "$CERTBOT_ENVIRONMENT" == "auto" ]; then
    if [[ "$(host "$domain")" != *"127.0.0.1"* && "$(host "$domain")" != *"localhost"* ]]; then
        CERTBOT_ENVIRONMENT="production"
    else
        CERTBOT_ENVIRONMENT="devel"
    fi
fi

echo "CERTBOT_ENVIRONMENT is set to: $CERTBOT_ENVIRONMENT"

  echo "Spracovanie domény $domain s IP adresou $ip_address..."

  # Krok 1: Generovanie Nginx konfigurácie pre HTTP (port 80)
  cat <<EOL > "$DEFAULT_CONF"
server {
    listen 80;
    server_name $domain;

    # Let's Encrypt overenie
    location /.well-known/acme-challenge/ {
        root $CHALLENGE_DIR;
        allow all;
    }

    # Redirect HTTP na HTTPS (vytvorené neskôr po úspešnom certifikáte)
    #location / {
    #    return 301 https://\$host\$request_uri;
    #}
}
EOL

  echo "Nginx konfigurácia pre HTTP (port 80) bola úspešne vytvorená."

  # Reštartovanie Nginxu pre povolenie HTTP prístupu
  service nginx stop && service nginx start

  if [[ $CERTBOT_ENVIRONMENT == "devel" ]]; then
    echo "Generovanie certifikátu pre $domain pomocou mkcert..."

    # Generovanie certifikátu pomocou mkcert
    mkdir -p /etc/nginx/ssl
    mkcert -cert-file /etc/nginx/ssl/$domain.pem \
           -key-file /etc/nginx/ssl/$domain-key.pem \
           "$domain"

    CERT_PATH="/etc/nginx/ssl/$domain.pem"
    KEY_PATH="/etc/nginx/ssl/$domain-key.pem"

    echo "Certifikát bol úspešne vygenerovaný pre $domain pomocou mkcert."
  else
    echo "Generovanie certifikátu pre $domain pomocou Certbota..."
    
    certbot certonly \
      --nginx \
      -w "$CHALLENGE_DIR" \
      -d "$domain" \
      --non-interactive \
      --agree-tos \
      --email "$CERTBOT_EMAIL"

    if [[ $? -ne 0 ]]; then
      echo "Chyba pri generovaní certifikátu pre $domain pomocou Certbota."
      continue
    fi

    CERT_PATH="/etc/letsencrypt/live/$domain/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$domain/privkey.pem"

    echo "Certifikát bol úspešne vygenerovaný pre $domain pomocou Certbota."
  fi

  # Krok 2: Generovanie Nginx konfigurácie pre HTTPS (port 443)
  cat <<EOL >> "$DEFAULT_CONF"
server {
    listen 443 ssl http2;
    server_name $domain;

    # SSL certifikáty
    ssl_certificate $CERT_PATH;
    ssl_certificate_key $KEY_PATH;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Zabezpečené hlavičky
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Proxy nastavenia
    location / {
        proxy_pass http://$ip_address;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Let's Encrypt overenie
    location /.well-known/acme-challenge/ {
        root $CHALLENGE_DIR;
        allow all;
    }
}
EOL
  echo "Nginx konfigurácia pre HTTPS (port 443) bola úspešne vygenerovaná."

  # Reštartovanie Nginxu pre aktiváciu HTTPS
  service nginx stop && service nginx start

done

echo "Certbot/mkcert a generovanie Nginx konfigurácie dokončené."

sleep infinity
