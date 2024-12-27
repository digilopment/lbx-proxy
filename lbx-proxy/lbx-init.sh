#!/bin/bash

set -e

JSON_FILE="/config/domains.json"
NGINX_CONF_DIR="/etc/nginx/conf.d"
TEMPLATE="/etc/nginx/templates/default.conf.template"
TEMP_TEMPLATE="/etc/nginx/templates/temp.conf.template"

# Check if JSON file exists
if [[ ! -f $JSON_FILE ]]; then
  echo "JSON file not found at $JSON_FILE"
  exit 1
fi

# Parse JSON and create temporary Nginx configuration for HTTP
jq -r '.domains | to_entries[] | "\(.key) \(.value)"' $JSON_FILE | while read -r domain ip; do
  TEMP_CONF_FILE="${NGINX_CONF_DIR}/${domain}_temp.conf"
  echo "Creating temporary config for $domain -> $ip"
  sed -e "s|{{DOMAIN}}|$domain|g" \
      -e "s|{{IP_ADDRESS}}|$ip|g" \
      $TEMP_TEMPLATE > $TEMP_CONF_FILE
done

# Test and reload Nginx with temporary configurations
echo "Testing Nginx configuration..."
nginx -t || { echo "Nginx configuration test failed!"; exit 1; }
echo "Reloading Nginx with temporary configurations..."
#nginx -s reload

# Generate certificates using Certbot
jq -r '.domains | keys[]' $JSON_FILE | while read -r domain; do
  echo "Obtaining certificate for $domain"
  certbot --nginx -d "$domain" --non-interactive --agree-tos --email admin@example.com || {
    echo "Failed to obtain certificate for $domain. Skipping."
  }
done

# Replace temporary configurations with final SSL configurations
jq -r '.domains | to_entries[] | "\(.key) \(.value)"' $JSON_FILE | while read -r domain ip; do
  CERT_PATH="/etc/letsencrypt/live/$domain/fullchain.pem"
  KEY_PATH="/etc/letsencrypt/live/$domain/privkey.pem"
  CONF_FILE="${NGINX_CONF_DIR}/${domain}.conf"
  
  echo "Replacing temporary config with final SSL config for $domain"
  sed -e "s|{{DOMAIN}}|$domain|g" \
      -e "s|{{IP_ADDRESS}}|$ip|g" \
      -e "s|{{CERT_PATH}}|$CERT_PATH|g" \
      -e "s|{{KEY_PATH}}|$KEY_PATH|g" \
      $TEMPLATE > $CONF_FILE

  # Remove temporary configuration
  rm -f "${NGINX_CONF_DIR}/${domain}_temp.conf"
done

# Test and reload Nginx with final configurations
echo "Testing Nginx configuration..."
nginx -t || { echo "Nginx configuration test failed!"; exit 1; }
echo "Reloading Nginx with final configurations..."
#nginx -s reload

# Start Nginx in the foreground
echo "Starting Nginx..."
nginx -g "daemon off;"

