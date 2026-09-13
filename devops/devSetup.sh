#!/bin/bash

. ~/devops/settings.sh

DBA_USER=''
DBA_PASSWORD=''

echo "Your settings are taken from ~/devops/settings.sh"
echo
echo "To proceed you will need to enter the DBA username and password."
echo

while [ "${DBA_USER}" == '' ]; do
  read -p "Database Admin username: " DBA_USER  
  echo ""
  [ "${DBA_USER}" == '' ] && echo "Database Admin username must be specified."
done

while [ "${DBA_PASSWORD}" == '' ]; do
  read -sp "Database Admin password: " DBA_PASSWORD
  echo ""
  [ "${DBA_PASSWORD}" == '' ] && echo "Database Admin password must be specified."
done


sqlplus ${DBA_USER}/${DBA_PASSWORD}@${DB_NAME} @devSetup ${DBTWIG_USER} ${DBTWIG_PASS}<<EOF
exit
EOF


