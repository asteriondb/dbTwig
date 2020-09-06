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

sqlplus dbtwig/dbtwig@local-dev @extractPackageHeader db_twig ../dba/oracle 
sqlplus dbtwig/dbtwig@local-dev @preWrapPackageBody db_twig ../dba/oracle
wrappedCheck ../dba/oracle/db_twig.pls
$SQLPATH/end_package_input.sh >>../dba/oracle/db_twig.pls
$SQLPATH/show_errors.sh db_twig >>../dba/oracle/db_twig.pls 

sqlplus dbtwig_tutorials/dbtwig_tutorials@local-dev @extractPackageHeader react_example /jjflash/git/asterionDB/dbTwig/examples/react/dba
sqlplus dbtwig_tutorials/dbtwig_tutorials@local-dev @preWrapPackageBody react_example /jjflash/git/asterionDB/dbTwig/examples/react/dba
wrappedCheck /jjflash/git/asterionDB/dbTwig/examples/react/dba/react_example.pls
$SQLPATH/end_package_input.sh >>../examples/react/dba/react_example.pls
$SQLPATH/show_errors.sh react_example >>../examples/react/dba/react_example.pls 

