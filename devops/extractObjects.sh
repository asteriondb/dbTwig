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

sqlplus $DBTWIG_USER/$DBTWIG_PASS@$DB_NAME @extractPackageHeader db_twig ../dba 
sqlplus $DBTWIG_USER/$DBTWIG_PASS@$DB_NAME @preWrapPackageBody db_twig ../dba
wrappedCheck ../dba/oracle/db_twig.pls
$SQLPATH/end_package_input.sh >>../dba/db_twig.pls
$SQLPATH/show_errors.sh db_twig >>../dba/db_twig.pls 

sqlplus $TUTORIAL_USER/$TUTORIAL_PASS@$DB_NAME @extractPackageHeader react_example ../examples/react/dba
sqlplus $TUTORIAL_USER/$TUTORIAL_PASS@$DB_NAME @preWrapPackageBody react_example ../examples/react/dba
wrappedCheck /storage/git/dbTwig/examples/react/dba/react_example.pls
$SQLPATH/end_package_input.sh >>../examples/react/dba/react_example.pls
$SQLPATH/show_errors.sh react_example >>../examples/react/dba/react_example.pls 

sqlplus $TUTORIAL_USER/$TUTORIAL_PASS@$DB_NAME @/home/asterion/git/dbTwig/dba/extractDbTwigData /home/asterion/git/dbTwig/examples/react/dba/dbTwigData.sql reactExample
