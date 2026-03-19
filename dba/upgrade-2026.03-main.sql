/*



*/

define dbtwig_user = '&1'

spool $HOME/asterion/oracle/dbTwig/dba/upgrade-2026.03-main.log
whenever sqlerror exit

set echo on

alter session set current_schema = &dbtwig_user;
whenever sqlerror continue

REM  Put stuff between here.....



REM  ...and here

@$HOME/asterion/oracle/dbTwig/dba/db_twig
@$HOME/asterion/oracle/dbTwig/dba/db_twig.pls

@$HOME/asterion/oracle/dbTwig/dba/call_restapi
@$HOME/asterion/oracle/dbTwig/dba/get_column_length

prompt 
spool off;

