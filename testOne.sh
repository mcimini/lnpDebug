#!/bin/bash

shopt -s nullglob

here="$(dirname "$0")"
cd "$here/generated"

abella -a "$1" > "$1".output.txt 

if [ $? -eq 0 ]
then
    echo -e "Succeded: $1\n"
else
    echo -e "Failed: $1\n"
fi
