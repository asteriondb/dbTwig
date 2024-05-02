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
set echo on

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

create synonym &5..call_restapi for &4..call_restapi;

alter session set current_schema = &4;

create table dbtwig_profile
(
  production_mode                   varchar2(1) default 'Y'
   constraint prod_mode_chk check (production_mode in ('Y', 'N')) not null
);

insert into dbtwig_profile values ('Y');
commit;

create table db_twig_services
(
  service_name                      varchar2(128) primary key,
  service_owner                     varchar2(128) not null,
  production_mode                   varchar2(1) default 'Y'
   constraint svc_prod_mode_chk check (production_mode in ('Y', 'N')) not null,
  session_validation_procedure      varchar2(256) not null,
  api_error_handler                 varchar2(256) not null,
  log_all_requests                  varchar2(1) default 'N'
   constraint log_all_requests_chk check (log_all_requests in ('Y', 'N')) not null
);

create table db_twig_errors
(
  error_timestamp                   timestamp default systimestamp at time zone 'utc' not null,
  error_code                        number(6) not null,
  json_parameters                   clob not null,
  error_message                     clob
);

create table logged_requests
(
  request_timestamp                 timestamp default systimestamp at time zone 'utc' not null,
  request                           clob 
    constraint request_chk check (request is json) not null
);

@@db_twig
@@db_twig.pls

@@call_restapi.sql

grant execute on call_restapi to &5;

exit;
