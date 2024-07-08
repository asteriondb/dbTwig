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

define dba_user = '&1'
define dba_password = '&2'
define database_name = '&3'
define dbtwig_user = '&4'
define dbtwig_listener = '&5'
define middle_tier_password = '&6'

connect &dba_user/"&dba_password"@"&database_name";

set termout off
set echo on

@setupSchema

create synonym &dbtwig_listener..call_restapi for &dbtwig_user..call_restapi;

alter session set current_schema = &dbtwig_user;

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

grant execute on call_restapi to &dbtwig_listener;

exit;
