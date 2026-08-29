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

sqlplus $EMAIL_USER/$EMAIL_PASS@$DB_NAME @extractObjects $GIT_HOME

wrappedCheck $GIT_HOME/dbTwig/email/dba/restapi.pls
$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/email/dba/restapi.pls
$SQLPATH/show_errors.sh restapi >>$GIT_HOME/dbTwig/email/dba/restapi.pls 

wrappedCheck $GIT_HOME/dbTwig/email/dba/email.pls
$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/email/dba/email.pls
$SQLPATH/show_errors.sh email >>$GIT_HOME/dbTwig/email/dba/email.pls 


