#!/bin/bash

output="reach.json"
coffee="./node_modules/.bin/coffee"
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -f "$coffee" ]
then
  coffee "$dir/src/" > $output
  echo "Output stored in: $output"
else
  echo "Depdendencies not installed, run npm install"
fi

