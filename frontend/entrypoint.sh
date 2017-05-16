#!/bin/sh

# Create a self-signed certificate, so that nginx will actually run.
if [ ! -e /etc/certs/live/privkey.pem ] || [ ! -e /etc/certs/live/fullchain.pem ]
then
    mkdir -p /etc/certs/live
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/certs/live/privkey.pem \
        -out /etc/certs/live/fullchain.pem \
        -subj /CN=${DOMAIN}
fi

exec nginx -g "daemon off;"
