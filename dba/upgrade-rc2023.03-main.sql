/*

Upgrade Notes

*/

define  s_git_tag  = 'rc2022.09'
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

@@db_twig
@@db_twig.pls

REM  ...and here

prompt 
spool off;

exit;
