FROM nginx:latest

# Install certbot and necessary tools
RUN apt-get update && apt-get install -y \
    certbot \
    python3-certbot-nginx \
    jq \
    iputils-ping && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy scripts and configuration templates
COPY lbx-init.sh /usr/local/bin/lbx-init.sh
RUN chmod +x /usr/local/bin/lbx-init.sh

# Copy the configuration templates
COPY templates/default.conf.template /etc/nginx/templates/default.conf.template
COPY templates/temp.conf.template /etc/nginx/templates/temp.conf.template

# Set the entrypoint script
ENTRYPOINT ["/usr/local/bin/lbx-init.sh"]

