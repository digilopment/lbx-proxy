#!/bin/bash

set -e

# Cesta k JSON súboru s doménami
JSON_FILE="/config/domains.json"
NGINX_CONF_DIR="/etc/nginx/conf.d"
CERTBOT_CONTAINER="certbot"
CHALLENGE_DIR="/var/www/certbot"
ENVIRONMENT="production" # Nastav na "devel" pre mkcert

# Skontrolovať, či JSON súbor existuje
if [[ ! -f $JSON_FILE ]]; then
  echo "JSON file not found: $JSON_FILE"
  #exit 1
fi

# Vymazať starý súbor default.conf
DEFAULT_CONF="${NGINX_CONF_DIR}/default.conf"
> "$DEFAULT_CONF"

# Parsovanie JSON a generovanie certifikátov pre každú doménu
jq -r '.domains | to_entries[] | "\(.key) \(.value)"' "$JSON_FILE" | while read -r domain ip_address; do
  echo "Spracovanie domény $domain s IP adresou $ip_address..."

  if [[ $ENVIRONMENT == "devel" ]]; then
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

    # Spustenie Certbot príkazu
    certbot certonly \
      --staging \
      --standalone \
      -w "$CHALLENGE_DIR" \
      -d "$domain" \
      --non-interactive \
      --agree-tos \
      --debug-challenges \
      --email thomas.doubek@gmail.com || echo "Certbot failed, but continuing execution."

    CERT_PATH="/etc/letsencrypt/live/$domain/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$domain/privkey.pem"

    if [[ $? -ne 0 ]]; then
      echo "Chyba pri generovaní certifikátu pre $domain pomocou Certbota."
      continue
    fi

    echo "Certifikát bol úspešne vygenerovaný pre $domain pomocou Certbota."
  fi

  # Generovanie Nginx konfigurácie
  cat <<EOL >> "$DEFAULT_CONF"
server {
    listen 80;
    server_name $domain;
    
    # Presmerovanie HTTP na HTTPS
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

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
        root /var/www/certbot;
    }
}
EOL
  echo "Nginx konfigurácia pre $domain bola úspešne vygenerovaná."
done

# Uistite sa, že container stále beží
echo "Certbot/mkcert a generovanie Nginx konfigurácie dokončené."
#sleep 1000
service nginx stop && service nginx start
sleep infinity
