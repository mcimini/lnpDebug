#!/bin/bash

shopt -s nullglob

langFile=${*: -1:1}
thmFile="${langFile%.*}".thm

./lnp --debug $@
./testOne.sh "$thmFile" 2> dump.txt
rm dump.txt
./lnpdebug ./generated/"$thmFile"

# tests to see how those works
#langFile=${*: -1:1}
#echo $@
#echo $langFile
#echo "${langFile%.*}".thm

