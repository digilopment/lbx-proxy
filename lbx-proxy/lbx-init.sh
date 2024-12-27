#!/bin/bash

set -e

JSON_FILE="/config/domains.json"
NGINX_CONF_DIR="/etc/nginx/conf.d"
TEMPLATE="/etc/nginx/templates/default.conf.template"

# Check if JSON file exists
if [[ ! -f $JSON_FILE ]]; then
  echo "JSON file not found at $JSON_FILE"
  exit 1
fi

# Parse JSON and create Nginx configuration
jq -r '.domains | to_entries[] | "\(.key) \(.value)"' $JSON_FILE | while read -r domain ip; do
  CERT_PATH="/etc/letsencrypt/live/$domain/fullchain.pem"
  KEY_PATH="/etc/letsencrypt/live/$domain/privkey.pem"

  # Check if certificate exists
  if [[ ! -f $CERT_PATH || ! -f $KEY_PATH ]]; then
    echo "Certificate not found for $domain. Generating self-signed certificate."
    mkdir -p "/etc/letsencrypt/live/$domain"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "/etc/letsencrypt/live/$domain/privkey.pem" \
      -out "/etc/letsencrypt/live/$domain/fullchain.pem" \
      -subj "/CN=$domain"
  fi

  # Create Nginx configuration
  conf_file="${NGINX_CONF_DIR}/${domain}.conf"
  echo "Creating config for $domain -> $ip"
  sed -e "s|{{DOMAIN}}|$domain|g" \
      -e "s|{{IP_ADDRESS}}|$ip|g" \
      -e "s|{{CERT_PATH}}|$CERT_PATH|g" \
      -e "s|{{KEY_PATH}}|$KEY_PATH|g" \
      $TEMPLATE > $conf_file
done

# Test and reload Nginx
echo "Testing Nginx configuration..."
nginx -t || { echo "Nginx configuration test failed!"; exit 1; }

#echo "Reloading Nginx..."
#nginx -s reload

# Generate certificates using certbot
jq -r '.domains | keys[]' $JSON_FILE | while read -r domain; do
  CERT_PATH="/etc/letsencrypt/live/$domain/fullchain.pem"
  
  if [[ ! -f $CERT_PATH ]]; then
    echo "Obtaining certificate for $domain"
    certbot --nginx -d "$domain" --non-interactive --agree-tos --email admin@example.com || {
      echo "Failed to obtain certificate for $domain. Skipping."
    }
  else
    echo "Certificate already exists for $domain"
  fi
done

# Start Nginx in the foreground
echo "Starting Nginx..."
nginx -g "daemon off;"

