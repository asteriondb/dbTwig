/*

Upgrade Notes

*/

define  s_git_tag  = 'rc2022.03'
define  s_git_branch = 'main'

spool upgrade-&s_git_tag-&s_git_branch..log

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

alter table db_twig_services add session_validation_procedure varchar2(256);

update  db_twig_services
   set  session_validation_procedure = 'object_vault_restapi.validate_session';

alter table db_twig_services modify session_validation_procedure not null;

@@db_twig
@@db_twig.plb

REM  ...and here

prompt 
spool off;

exit;
