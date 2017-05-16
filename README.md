Chibitronics Server Infrastructure
===========================

Support documents and files for deploying the Chibitronics Love-to-Code
server infrastructure.


Quickstart
==========

Install Docker.  Then run:

    docker network create ltc-network
    docker run -d --net=ltc-network --name ltc-compiler xobs/ltc-compiler
    docker run -p 8080:80 -d --net=ltc-network --name ltc-ux xobs/ltc-ux

Then open a web browser connect to localhost:8080

Hosted
======

If you want to run a server on Digital Ocean, you can use Terraform to spin up a server.

    cd tf
    terraform apply


Building Containers
===================

The containers are hosted in their own repos.


Website: https://github.com/chibitronics/ltc-webview-layer/

Compiler: https://github.com/chibitronics/ltc-compiler-layer

Network
-------

Containers refer to each other using their names.  Be sure to put everything on the same network:

    docker network create ltc


CoreOS Setup
============

1. Set up a docker network:
    docker network create ltc
2. Run the compiler:
    docker run \
        -d \
        --name ltc-compiler \
        --network ltc \
        --restart always \
        chibitronics/ltc-compiler-amd64
3. Run the frontend:
    docker run 
        -d \
        --name ltc-webview \
        --network ltc \
        --restart always \
        -e COMPILE_URL=/compile \
        chibitronics/ltc-webview-amd64
4. Run the frontend:
   docker run \
        -d \
        --name ltc-frontend \
        --restart always \
        --network ltc \
        -p 80:80 \
        -p 443:443 \
        -e DOMAIN=ltc.chibitronics.com \
        -v /opt/certs:/etc/certs \
        --add-host acme-renewal:188.166.197.248 \
        chibitronics/ltc-frontend-amd64


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
