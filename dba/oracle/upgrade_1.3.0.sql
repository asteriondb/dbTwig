/*

Upgrade Notes

*/

spool upgrade_1.3.0.log

PROMPT To proceed, you will have to connect to the database as a DBA.
PROMPT

accept dba_user prompt "Enter a user name that can connect to the database as a DBA: "
accept dba_pass prompt "Enter the DBA password: " hide

whenever sqlerror exit
connect &&dba_user/&&dba_pass;

prompt
accept dbtwig prompt "Enter the name of the user that owns the DbTwig schema [dbtwig]: " default dbtwig
prompt

alter session set current_schema = &&dbtwig;

whenever sqlerror continue

REM  Put stuff between here.....

alter table db_twig_services add replace_error_stack varchar2(1) default 'Y'
  constraint replace_stack_chk check (replace_error_stack in ('Y', 'N')) not null;

@@db_twig.plb

REM  ...and here

prompt 
spool off;

exit;
