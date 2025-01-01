FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        nginx-extras \
        vim \
        openssl \
        ca-certificates \
        git \
        certbot \
        mkcert \
        nano \
        python3-certbot-nginx \
        jq \
        iputils-ping && \
    apt-get clean

RUN useradd -r nginx

# Create the /var/www/certbot directory for Let's Encrypt challenges
RUN mkdir -p /var/www/certbot/.well-known/acme-challenge && \
    mkdir -p /etc/nginx/ssl && \
    chown -R www-data:www-data /var/www/certbot && \
    chmod 0777 -R /var/www/certbot

# Copy scripts and default files
COPY lbx-init.sh /usr/local/bin/lbx-init.sh
RUN chmod +x /usr/local/bin/lbx-init.sh
COPY config/nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/lbx-init.sh"]

#CMD ["nginx", "-g", "daemon off;"]
