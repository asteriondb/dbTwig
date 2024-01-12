#!/bin/bash

set -e

cd ../dba
sqlplus /nolog @install

echo "Installation successful. You can run the demo web-app with 'serve -s -l 5000 build' from the reactDemo subdirectory."
