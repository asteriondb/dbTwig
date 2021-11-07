rem  Copyright (c) 2020 By AsterionDB Inc.
rem
rem  install.sql 	AsterionDB DbTwig Middle Tier Framework
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script drives the creation of all required objects for the DbTwig Middle Tier Framework
rem
rem  Invocation: sqlplus /nolog @install $DBA_USER $DBA_PASSWORD $DATABASE_NAME $DBTWIG_USER $DBTWIG_LISTENER $MIDDLE_TIER_PASSWORD

whenever sqlerror exit failure;

set verify off
spool install.log

connect &1/"&2"@"&3";

set termout off
set echo off

declare

    l_sql_text                        clob;
    l_default_tablespace              database_properties.property_value%type;

begin

    select  property_value
      into  l_default_tablespace
      from  database_properties 
     where  property_name = 'DEFAULT_PERMANENT_TABLESPACE';

    l_sql_text := 'create user &4';
    execute immediate l_sql_text;

    l_sql_text := 'alter user &4 quota 50M on '||l_default_tablespace;
    execute immediate l_sql_text;

    l_sql_text := 'grant create session to &5 identified by "&6"';
    execute immediate l_sql_text;

end;
.
/

create synonym &5..db_twig for &4..db_twig;

alter session set current_schema = &4;

create table db_twig_services
(
  service_name                      varchar2(128) primary key,
  service_owner                     varchar2(128) not null,
  replace_error_stack               varchar2(1) default 'Y'
   constraint replace_stack_chk check (replace_error_stack in ('Y', 'N')) not null,
  session_validation_procedure      varchar2(256) not null
);

create table db_twig_errors
(
  error_timestamp                   timestamp default systimestamp at time zone 'utc' not null,
  error_code                        number(6) not null,
  json_parameters                   clob,
  error_message                     clob
);

@@db_twig
@@db_twig.pls

grant execute on db_twig to &5;

exit;
