Chibitronics Server Infrastructure
===========================

Support documents and files for deploying the Chibitronics Love-to-Code
server infrastructure.


Quickstart
==========

Install Docker.  Then run:

    docker network create ltc-network
    docker run -d --network ltc-network --name ltc-compiler xobs/ltc-compiler:1.6
    docker run -d --network ltc-network --name ltc-compiler-frontend xobs/ltc-compiler-frontend:1.6
    docker run -d --network ltc-network --name ltc-ux xobs/ltc-ux:1.4
    docker run -p 8080:80 -d --network ltc-network --name ltc-frontend xobs/ltc-frontend:1.1


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

    docker build -t xobs/ltc-compiler:1.8 compiler/

Run the compiler with the following Docker arguments:

    docker run -d --network ltc-network --name ltc-compiler xobs/ltc-compiler:1.8

To save build files, bind /tmp/cache/filebkp/ to a local path:

    docker run -d --network ltc-network -v $(pwd)/filebkp:/var/cache/filebkp --name ltc-compiler xobs/ltc-compiler:1.8

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

    docker build -t xobs/ltc-ux:1.5 ux/

Run:

    docker run -d --network ltc-network --name ltc-ux xobs/ltc-ux:1.5

To do development on the frontend, check out the web page locally, and run ltc-ux with a local volume:

    git clone git@github.com:xobs/codebender-test-shell.git
    docker run -d --network ltc-network -v $(pwd)/codebender-test-shell/app:/usr/share/nginx/html --name ltc-ux xobs/ltc-ux:1.4

Frontend
----------

This server acts as a frontend to the compiler, UX, and API servers.

 Build:

    docker build -t xobs/ltc-frontend:1.1 frontend/

 Run:

    docker run -p 8080:80 -d --network ltc-network --name ltc-frontend xobs/ltc-frontend:1.1
