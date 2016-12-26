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


UX: https://github.com/xobs/ltc-ux

Compiler: https://github.com/xobs/ltc-compiler

Network
-------

Containers refer to each other using their names.  Be sure to put everything on the same network:

    docker network create ltc-network