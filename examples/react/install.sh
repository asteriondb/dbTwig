#!/bin/bash

set -e

cd dba
sqlplus /nolog @install

echo "Installing Node-JS serve program...sudo access required..."
sudo npm install -g serve




