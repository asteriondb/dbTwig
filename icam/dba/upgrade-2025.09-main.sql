/*



*/

define icam_user = '&1'

spool $HOME/asterion/oracle/dbTwig/icam/dba/upgrade-2025.09-main.log
whenever sqlerror exit

set echo on

alter session set current_schema = &icam_user;
whenever sqlerror continue

REM  Put stuff between here.....

REM  ...and here

set echo on

delete  from middle_tier_map
 where  object_group in ('icam');

commit;

@$HOME/asterion/oracle/dbTwig/icam/dba/dbTwigData
commit;

@$HOME/asterion/oracle/dbTwig/icam/dba/loadPackages

prompt 
spool off;

