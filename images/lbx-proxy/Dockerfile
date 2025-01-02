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
        bind9-host \
        nano \
        cron \
        certbot \
        curl \
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
COPY lbx-init.sh /usr/local/bin/lbx-renew.sh
RUN chmod +x /usr/local/bin/lbx-init.sh
RUN chmod +x /usr/local/bin/lbx-renew.sh

COPY config/nginx.conf /etc/nginx/nginx.conf

# Create the cron job file
RUN echo "30 * * * * /usr/local/bin/renew-certbot.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/renew-certbot

# Set the correct permissions for the cron job file
RUN chmod 0644 /etc/cron.d/renew-certbot

# Apply the cron job to the cron daemon
RUN crontab /etc/cron.d/renew-certbot

EXPOSE 80 443

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/lbx-init.sh"]

#CMD ["nginx", "-g", "daemon off;"]
