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

sqlplus $ICAM_USER/$ICAM_PASS@$DB_NAME @extractObjects $GIT_HOME

wrappedCheck $GIT_HOME/dbTwig/icam/dba/restapi.pls
$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/icam/dba/restapi.pls
$SQLPATH/show_errors.sh restapi >>$GIT_HOME/dbTwig/icam/dba/restapi.pls 

wrappedCheck $GIT_HOME/dbTwig/icam/dba/icam.pls
$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/icam/dba/icam.pls
$SQLPATH/show_errors.sh icam >>$GIT_HOME/dbTwig/icam/dba/icam.pls 


