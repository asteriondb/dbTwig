rem  Copyright (c) 2019 By AsterionDB Inc.
rem
rem  remove.sql 	AsterionDB DbTwig Middle Tier Framework
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script will remove the React Example.
rem
rem  Invocation: sqlplus /nolog @remove

whenever sqlerror exit failure;

set verify off
spool install.log

PROMPT To proceed, you will have to connect to the database as a DBA.
PROMPT

accept dba_user prompt "Enter a user name that can connect to the database as a DBA: "
accept dba_pass prompt "Enter the DBA password: " hide

connect &&dba_user/&&dba_pass;

prompt
accept dbtwig_user prompt "Enter the name of the user that owns the DbTwig schema [dbtwig]: " default dbtwig
prompt

prompt
accept react_example_user prompt "Enter the name of the DbTwig Example schema owner [react_example]: " default react_example
prompt

set echo on

drop user &&react_example_user cascade;

alter session set current_schema = &&dbtwig_user;

delete
  from  db_twig_services
 where  service_name = 'reactExample'
   and  service_owner = '&&react_example_user';

spool off;
exit;

