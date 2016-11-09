Chibitronics Server Infrastructure
===========================

Support documents and files for deploying the Chibitronics Love-to-Code
server infrastructure.

Network
-------

Create a new network for everything to live on:

    docker network create ltc-network

Compiler
--------

Build the compiler container with:

     docker build -t xobs/ltc-compiler:1.1 compiler/

Run the compiler with the following Docker arguments:

    docker run -d -e CODEBENDER_AUTHORIZATION_KEY=fantasticpass4242 --network ltc-network --name ltc-compiler xobs/ltc-compiler:1.1


UX
------

This is the server that hosts files the users see.

Build:

    docker build -t xobs/ltc-ux:1.0 ux/

Run:

    docker run -d -v ${ux-src-dir}:/usr/share/nginx/html --network ltc-network --name ltc-ux xobs/ltc-ux:1.0


Frontend
---------

This server acts as a frontend to the compiler, UX, and API servers.

Build:

    docker build -t xobs/ltc-frontend:1.0 frontend/

Run:

    docker run -p 8080:80 -d --network ltc-network --name ltc-frontend xobs/ltc-frontend:1.0

Reload configuration:

    docker kill -s HUP ltc-frontend