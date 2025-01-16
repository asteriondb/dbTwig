#!/bin/bash

. $HOME/devops/settings.sh

set -e

cd "$(dirname "$0")"

sqlplus $TUTORIAL_USER/$TUTORIAL_PASS@$DB_NAME @extractObjects $GIT_HOME

$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/examples/dba/dbtwig_example.pls
$SQLPATH/show_errors.sh dbtwig_example >>$GIT_HOME/dbTwig/examples/dba/dbtwig_example.pls 

cat $GIT_HOME/common/devops/setApiToken.ed | ed $GIT_HOME/dbTwig/examples/dba/dbtwig_example.pls

$SQLPATH/end_package_input.sh >>$GIT_HOME/dbTwig/examples/dba/restapi.pls
$SQLPATH/show_errors.sh restapi >>$GIT_HOME/dbTwig/examples/dba/restapi.pls 

