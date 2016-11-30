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

The compiler is based on a reduced set of the Arduino toolchain with a simplified version of the Codebender compiler running on a PHP FastCGI module.

Build the compiler container with:

    docker build -t xobs/ltc-compiler:1.6 compiler/

Run the compiler with the following Docker arguments:

    docker run -d --network ltc-network --name ltc-compiler xobs/ltc-compiler:1.6

The compiler will now be listening on ltc-compiler:9000.


Compiler Frontend
-----------------

Because the compiler exposes a FastCGI interface, we need a small web server to go from FastCGI to http.  We use an nginx server running in a contianer called ltc-compiler-frontend.

Build the container with:

    docker build -t xobs/ltc-compiler-frontend:1.6 compiler-frontend/

Run the container with:

    docker run -d --network ltc-network --name ltc-compiler-frontend xobs/ltc-compiler-frontend:1.6

UX
------

This is the server that hosts files the users see.  It runs an nginx server that simply serves static files.

Build:

    docker build -t xobs/ltc-ux:1.4 ux/

Run:

    docker run -d --network ltc-network --name ltc-ux xobs/ltc-ux:1.4

Frontend
----------

This server acts as a frontend to the compiler, UX, and API servers.

 Build:

    docker build -t xobs/ltc-frontend:1.1 frontend/

 Run:

    docker run -p 8080:80 -d --network ltc-network --name ltc-frontend xobs/ltc-frontend:1.1
