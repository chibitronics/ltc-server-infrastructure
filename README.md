Chibitronics Server Infrastructure
===========================

Support documents and files for deploying the Chibitronics Love-to-Code
server infrastructure.


Quickstart
==========

Install Docker.  Then run:

    docker network create ltc-network
    docker run -d --net=ltc-network --name ltc-compiler xobs/ltc-compiler:1.10
    docker run -d --net=ltc-network --name ltc-compiler-frontend xobs/ltc-compiler-frontend:1.6
    docker run -d --net=ltc-network --name ltc-ux xobs/ltc-ux:1.5
    docker run -p 8080:80 -d --net=ltc-network --name ltc-frontend xobs/ltc-frontend:1.1


Hosted
======

If you want to run a server on Digital Ocean, you can use Terraform to spin up a server.

    cd tf
    terraform apply


Building Containers
===================


Network
-------

Containers refer to each other using their names.  Be sure to put everything on the same network:

    docker network create ltc-network

Compiler
--------

The compiler is based on a reduced set of the Arduino toolchain with a simplified version of the Codebender compiler running on a PHP FastCGI module.

Build the compiler container with:

    docker build -t xobs/ltc-compiler:1.11 compiler/

Run the compiler with the following Docker arguments:

    docker run -d --net=ltc-network --name ltc-compiler xobs/ltc-compiler:1.11

To save build files, bind /tmp/cache/filebkp/ to a local path:

    docker run -d --net=ltc-network -v $(pwd)/filebkp:/var/cache/filebkp --name ltc-compiler xobs/ltc-compiler:1.10

The compiler will now be listening on ltc-compiler:9000.


UX
------

This is the server that hosts files the users see.  It runs an nginx server that simply serves static files.

Build:

    docker build -t xobs/ltc-ux:1.6 ux/

Run:

    docker run -d --net=ltc-network --name ltc-ux xobs/ltc-ux:1.6

To do development on the frontend, check out the web page locally, and run ltc-ux with a local volume:

    git clone git@github.com:xobs/codebender-test-shell.git
    docker run -d --net=ltc-network -v $(pwd)/codebender-test-shell/app:/usr/share/nginx/html --name ltc-ux xobs/ltc-ux:1.4