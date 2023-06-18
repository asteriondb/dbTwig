#!/bin/bash

set -e

cd dba
sqlplus /nolog @install

echo "Installing Node-JS serve program...sudo access required..."
sudo npm install -g serve

echo "Installation successful. You can run the demo web-app with 'serve -s -l 5000 build' from the react subdirectory."
