
FROM nginx:latest

# Install certbot and necessary tools
RUN apt-get update && apt-get install -y \
    certbot \
    python3-certbot-nginx \
    jq \
    iputils-ping && \
    apt-get clean

# Copy scripts and default files
COPY lbx-init.sh /usr/local/bin/lbx-init.sh
RUN chmod +x /usr/local/bin/lbx-init.sh
COPY templates/default.conf.template /etc/nginx/templates/default.conf.template

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/lbx-init.sh"]
