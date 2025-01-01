#!/bin/bash

certbot renew --quiet

# Reštart nginx (alebo iný web server), ak sa certifikáty obnovili
if [ $? -eq 0 ]; then
   service nginx -s reload
else
    echo "Obnova certifikátov nebola potrebná alebo došlo k chybe."
fi
