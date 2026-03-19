/*



*/

define elog_user = '&1'

spool $HOME/asterion/oracle/dbTwig/errorLogger/dba/upgrade-2026.03-main.log
whenever sqlerror exit

set echo on

alter session set current_schema = &elog_user;
whenever sqlerror continue

REM  Put stuff between here.....



REM  ...and here

@$HOME/asterion/oracle/dbTwig/errorLogger/dba/error_logger
@$HOME/asterion/oracle/dbTwig/errorLogger/dba/error_logger.pls

prompt 
spool off;

