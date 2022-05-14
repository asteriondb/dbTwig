#!/bin/bash

. $HOME/devops/settings.sh

set -e

cd $GIT_HOME/dbTwig/devops

sqlplus $DBTWIG_USER/$DBTWIG_PASS@$DB_NAME @extractObjects $GIT_HOME

$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/dba/db_twig.pls
$SQLPATH/show_errors.sh db_twig >>$GIT_HOME/dbTwig/dba/db_twig.pls 


