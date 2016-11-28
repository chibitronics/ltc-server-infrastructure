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

    docker build -t xobs/ltc-compiler:1.3 compiler/

Run the compiler with the following Docker arguments:

    docker run -d --network ltc-network --name ltc-compiler xobs/ltc-compiler:1.3

The compiler will now be listening on ltc-compiler:9000.

UX
------

This is the server that hosts files the users see.  It runs an nginx server with a link at /compiler to ltc-compiler:9000/app.php

Build:

    docker build -t xobs/ltc-ux:1.1 ux/

Run:

    docker run -d -p 8080:80 --network ltc-network --name ltc-ux xobs/ltc-ux:1.1