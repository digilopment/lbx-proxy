#!/bin/bash

set -e

# File paths and container configurations
JSON_FILE="/config/domains.json"
CERTBOT_CONTAINER="certbot"
CHALLENGE_DIR="/var/www/certbot"
NGINX_CONF_DIR="/etc/nginx/conf.d"
TEMPLATE="/etc/nginx/templates/default.conf.template"

# Skontrolovať, či JSON súbor existuje
if [[ ! -f $JSON_FILE ]]; then
  echo "JSON file not found: $JSON_FILE"
  exit 1
fi

# Function to generate Nginx config for each domain
generate_nginx_config() {
  local domain="$1"
  local ip="$2"
  local temp_conf_file="$NGINX_CONF_DIR/${domain}_temp.conf"

  echo "Creating temporary config for $domain -> $ip"
  sed -e "s|{{DOMAIN}}|$domain|g" \
      -e "s|{{IP_ADDRESS}}|$ip|g" \
      $TEMPLATE > "$temp_conf_file"
}

# Function to test and reload Nginx
reload_nginx() {
  echo "Testing Nginx configuration..."
  nginx -t || { echo "Nginx configuration test failed!"; exit 1; }
  
  echo "Reloading Nginx..."
  nginx -s reload || { echo "Failed to reload Nginx!"; exit 1; }
}

# Function to generate SSL certificates using Certbot
generate_certificates() {
  local domain="$1"
  
  echo "Generating certificate for $domain..."
  certbot certonly \
    --webroot -w "$CHALLENGE_DIR" \
    -d "$domain" \
    --non-interactive \
    --agree-tos \
    --email thomas.doubek@gmail.com
  
  if [[ $? -eq 0 ]]; then
    echo "Certificate successfully generated for $domain"
  else
    echo "Failed to generate certificate for $domain"
  fi
}

# Function to replace temporary Nginx config with SSL configuration
replace_with_ssl_config() {
  local domain="$1"
  local ip="$2"
  local cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
  local key_path="/etc/letsencrypt/live/$domain/privkey.pem"
  local conf_file="$NGINX_CONF_DIR/${domain}.conf"

  if [[ -f $cert_path && -f $key_path ]]; then
    echo "Replacing temporary config with SSL config for $domain"
    sed -e "s|{{DOMAIN}}|$domain|g" \
        -e "s|{{IP_ADDRESS}}|$ip|g" \
        -e "s|{{CERT_PATH}}|$cert_path|g" \
        -e "s|{{KEY_PATH}}|$key_path|g" \
        $TEMPLATE > "$conf_file"
  else
    echo "Certificate files for $domain not found, skipping SSL config replacement."
  fi
}

# Parsovanie JSON a spracovanie každej domény
jq -r '.domains | to_entries[] | "\(.key) \(.value)"' "$JSON_FILE" | while read -r domain ip; do
  # Generate temporary Nginx config for HTTP
  generate_nginx_config "$domain" "$ip"
  
  # Generate SSL certificate for the domain
  generate_certificates "$domain"
  
  # Replace temporary config with SSL config
  replace_with_ssl_config "$domain" "$ip"

  # Clean up temporary config
  rm -f "$NGINX_CONF_DIR/${domain}_temp.conf"
done

# Test and reload Nginx with final configurations
reload_nginx

# Start Nginx in the foreground
echo "Starting Nginx..."
nginx -g "daemon off;"

