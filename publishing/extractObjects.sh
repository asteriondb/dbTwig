#!/bin/bash

function wrappedCheck()
{
  echo 'Checking '$1' for wrapped code.'

  if grep -q wrapped $1
  then
    echo 'Wrapped code detected for' $1
    exit 1
  fi 
}

set -e

cd "$(dirname "$0")"

unset DBTWIG_USER

read -p "Enter the dbTwig schema username [dbtwig]: " DBTWIG_USER
[ "${DBTWIG_USER}" == '' ] && DBTWIG_USER="dbtwig"

unset DBTWIG_PASSWORD
prompt="Enter $DBTWIG_USER's password: "
while IFS= read -p "$prompt" -r -s -n 1 char
do
    if [[ $char == $'\0' ]]
    then
        break
    fi
    prompt='*'
    DBTWIG_PASSWORD+="$char"
done

sqlplus $DBTWIG_USER/$DBTWIG_PASSWORD@local-dev @extractPackageHeader db_twig ../dba/oracle 
sqlplus $DBTWIG_USER/$DBTWIG_PASSWORD@local-dev @preWrapPackageBody db_twig ../dba/oracle
wrappedCheck ../dba/oracle/db_twig.pls
$SQLPATH/end_package_input.sh >>../dba/oracle/db_twig.pls
$SQLPATH/show_errors.sh db_twig >>../dba/oracle/db_twig.pls 
