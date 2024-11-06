/*



*/

spool $HOME/asterion/oracle/dbTwig/dba/upgrade-rc2024.09-main.log

whenever sqlerror exit
alter session set current_schema = &1;
whenever sqlerror continue

REM  Put stuff between here.....

alter table db_twig_services add service_enabled varchar2(1) default 'Y' not null
  constraint service_enabled_chk check (service_enabled in ('Y', 'N'));

REM  ...and here

@$HOME/asterion/oracle/dbTwig/dba/db_twig
@$HOME/asterion/oracle/dbTwig/dba/db_twig.pls

@$HOME/asterion/oracle/dbTwig/dba/call_restapi

prompt 
spool off;

