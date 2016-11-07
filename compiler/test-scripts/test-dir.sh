#!/bin/bash
. test-config.sh

if [ -z $1 ]
then
    echo "Usage: $0 [directory] [fqbn]"
    echo "The fqbn argument is optional"
    exit 1
fi

# Convert a file using:
curl -X POST -H "Accept: application/json" -d "$(./fixit.pl $1 $2)" ${compiler_url}
