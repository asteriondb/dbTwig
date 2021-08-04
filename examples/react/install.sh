#!/bin/bash

set -e

cd dba
sqlplus /nolog @install

sudo npm install -g serve




