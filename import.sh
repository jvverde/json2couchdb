#!/bin/bash
#usage: ./import.sh couchDBURL file1 [file2 [... [fineN]]]
db=$1
shift
for f in $@ ; do
	curl -X POST $db -H "Content-Type:application/json" -d @$f
done 
