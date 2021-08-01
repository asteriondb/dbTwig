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

sqlplus $DBTWIG_USER/$DBTWIG_PASS@$DB_NAME @extractPackageHeader db_twig $GIT_HOME/dbTwig/dba 
sqlplus $DBTWIG_USER/$DBTWIG_PASS@$DB_NAME @preWrapPackageBody db_twig $GIT_HOME/dbTwig/dba
wrappedCheck $GIT_HOME/dbTwig/dba/db_twig.pls
$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/dba/db_twig.pls
$SQLPATH/show_errors.sh db_twig >>$GIT_HOME/dbTwig/dba/db_twig.pls 

wrap iname=$GIT_HOME/dbTwig/dba/db_twig.pls oname=$GIT_HOME/dbTwig/dba/db_twig.plb

sqlplus $TUTORIAL_USER/$TUTORIAL_PASS@$DB_NAME @extractPackageHeader react_example $GIT_HOME/dbTwig/examples/react/dba
sqlplus $TUTORIAL_USER/$TUTORIAL_PASS@$DB_NAME @preWrapPackageBody react_example $GIT_HOME/dbTwig/examples/react/dba
wrappedCheck $GIT_HOME/dbTwig/examples/react/dba/react_example.pls
$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/examples/react/dba/react_example.pls
$SQLPATH/show_errors.sh react_example >>$GIT_HOME/dbTwig/examples/react/dba/react_example.pls 

sqlplus $TUTORIAL_USER/$TUTORIAL_PASS@$DB_NAME @$GIT_HOME/dbTwig/dba/extractDbTwigData $GIT_HOME/dbTwig/examples/react/dba/dbTwigData.sql reactExample
