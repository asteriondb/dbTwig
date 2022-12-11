/*

Upgrade Notes

*/

define  s_git_tag  = 'rc2023.03'
define  s_git_branch = 'main'

spool upgrade-&s_git_tag-&s_git_branch..log

whenever sqlerror exit
connect &1/&2;

prompt
accept dbtwig prompt "Enter the name of the user that owns the DbTwig schema [dbtwig]: " default dbtwig
prompt

alter session set current_schema = &&dbtwig;

whenever sqlerror continue

REM  Put stuff between here.....

alter table db_twig_services add api_error_handler varchar2(256);

update  db_twig_services
   set  api_error_handler = 'unknown';

update  db_twig_services
   set  api_error_handler = 'restapi.restapi_error'
 where  service_name = 'asterionDB';

commit;

alter table db_twig_services modify api_error_handler not null;

@@db_twig
@@db_twig.pls

REM  ...and here

prompt 
spool off;

exit;
