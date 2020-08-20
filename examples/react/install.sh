#!/bin/bash

cd dba
sqlplus /nolog @install

cd ../javaScript/reactExample
npm install
npm run build

sudo npm install -g serve




