#!/bin/sh

#ip_address=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' codebender-compiler)
#ip_address=ltc-compiler.xobs.io
ip_address=localhost:8080
compiler_url=http://${ip_address}/key123/v2
