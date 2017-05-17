Chibitronics Server Infrastructure
===========================

Support documents and files for deploying the Chibitronics Love-to-Code
server infrastructure.


Quickstart
==========

If you would simply like to spin up the infrastructure, install Docker and run:

    docker network create ltc
    docker run -d --net=ltc --name=ltc-compiler chibitronics/ltc-compiler-amd64
    docker run -d --net=ltc --name=ltc-webview chibitronics/ltc-webview-amd64
    docker run -p 8080:80 -d --net=ltc --name=ltc-frontend chibitronics/ltc-frontend-amd64

Then open a web browser connect to localhost:8080

Building Containers
===================

The containers are hosted in their own repos.

Website: https://github.com/chibitronics/ltc-webview-layer/

Compiler: https://github.com/chibitronics/ltc-compiler-layer

Frontend: frontend/

Network
-------

Containers refer to each other using their names.  Be sure to put everything on the same network:

    docker network create ltc


CoreOS Setup
============

There is a file in the root called cloud-config.yaml.  It can be pasted into your cloud provider's "User Data" section, causing it to spin up an instance on its own.

If you already have the access keys, you can add a "write_files" directive.  Append cloud-config-extra.yaml to cloud-config.yaml and paste in your actual keys.


Renewing / Configuring Encryption
=================================

We use Certbot, part of LetsEncrypt.  The Frontend will create a dummy certificate when it starts up, because nginx won't start otherwise.

To generate a new certificate, run:

    docker run \
        -it \
        --rm \
        -p 8081:80 \
        -v /opt/letsencrypt:/etc/letsencrypt \
        certbot/certbot \
        certonly \
        --standalone \
        --email $YOUR_EMAIL_ADDRESS \
        --agree-tos \
        --preferred-challenges http \
        -n \
        -d $YOUR_DOMAIN

You can then copy /opt/letsencrypt/live/*/ to the servers.

    docker run \
        -it \
        --rm \
        -v /opt/letsencrypt:/etc/letsencrypt \
        certbot/certbot \
        renew

Copy the new certificate's 'fullchain.pem' and 'privkey.pem' to /opt/certs/live/ on the host.

To force the webserver to reload the new certificate, run:

    docker exec -it ltc-frontend nginx -s reload

DNS Setup
=========

1. Create named config files
2. Run bind: docker run --name=ltc-dns \
-it -d \
--dns=8.8.8.8 --dns=8.8.4.4 \
-p 53:53/udp -p 53:53 \
-v /opt/bind/conf:/etc/bind \
-v /opt/bind/cache:/var/cache/bind \
-v /opt/bind/log:/var/log/named \
ventz/bind
