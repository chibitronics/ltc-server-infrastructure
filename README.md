Chibitronics Server Infrastructure
===========================

Support documents and files for deploying the Chibitronics Love-to-Code
server infrastructure.


Compiler
--------

Build the compiler container with:

     docker build -t xobs/ch-compiler:1.0 compiler/

Run the compiler with the following Docker arguments:

    docker run -p 8080:80 -d -e CODEBENDER_AUTHORIZATION_KEY=fantasticpass4242 --name ch-compiler xobs/ch-compiler:1.0


UX
------

This is the server that hosts files the users see.

Build:

    docker build -t xobs/ch-ux:1.0 ux/

Run:

    docker run -p 8081:80 -d -v ${ux-src-dir}:/usr/share/nginx/html --name ch-ux xobs/ch-ux:1.0


Frontend
---------

This server acts as a frontend to the compiler, UX, and API servers.

Build:

    docker build -t xobs/ch-frontend:1.0 frontend/

Run:

    docker run -p 8082:80 -d --name ch-frontend xobs/ch-frontend:1.0