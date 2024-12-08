#!/bin/bash

. $HOME/devops/settings.sh

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

#
#  ObjectVault
#

sqlplus $ELOG_USER/$ELOG_PASS@$DB_NAME @extractObjects $GIT_HOME

wrappedCheck $GIT_HOME/dbTwig/errorLogger/dba/error_logger.pls
$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/errorLogger/dba/error_logger.pls
$SQLPATH/show_errors.sh error_logger >>$GIT_HOME/dbTwig/errorLogger/dba/error_logger.pls 


