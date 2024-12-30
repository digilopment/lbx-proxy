FROM ubuntu:latest

# Install certbot and necessary tools
RUN apt-get update && apt-get install -y nginx nginx-extras vim openssl ca-certificates git
RUN useradd -r nginx

RUN apt-get update && apt-get install -y \
    certbot mkcert \
    python3-certbot-nginx \
    jq \
    iputils-ping && \
    apt-get clean

# Create the /var/www/certbot directory for Let's Encrypt challenges
RUN mkdir -p /var/www/certbot && mkdir /etc/nginx/ssl && \
    chown -R www-data:www-data /var/www/certbot

# Copy scripts and default files
COPY lbx-init.sh /usr/local/bin/lbx-init.sh
RUN chmod +x /usr/local/bin/lbx-init.sh
COPY config/nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/lbx-init.sh"]

#CMD ["nginx", "-g", "daemon off;"]
