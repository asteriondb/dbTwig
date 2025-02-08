rem  Copyright (c) 2019, 2025 By AsterionDB Inc.
rem
rem  install.sql 	AsterionDB Database Vault v1.0
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script drives the creation of all required objects for the AsterionDB Converged Computing Platform.
rem
rem  Invocation:
rem
rem  sqlplus /nolog @install $DBA_USER $DBA_PASSWORD $DATABASE_NAME $DBTWIG_USER $ELOG_USER
rem

whenever sqlerror exit failure;

set verify on
spool $HOME/asterion/oracle/dbTwig/errorLogger/dba/install.log

define dba_user = '&1'
define dba_password = '&2'
define database_name = '&3'
define dbtwig_user = '&4'
define elog_user = '&5'

connect &dba_user/"&dba_password"@"&database_name";

set termout off
set echo on

whenever sqlerror continue

@$HOME/asterion/oracle/dbTwig/errorLogger/dba/setupSchema

grant references(service_id) on &dbtwig_user..db_twig_services to &elog_user;
grant execute on &dbtwig_user..get_column_length to &elog_user;
grant execute on &dbtwig_user..db_twig to &elog_user;

create or replace synonym &elog_user..db_twig_services for &dbtwig_user..db_twig_services;
create or replace synonym &elog_user..get_column_length for &dbtwig_user..get_column_length;
create or replace synonym &elog_user..db_twig for &dbtwig_user..db_twig;

alter session set current_schema = &elog_user;

create sequence id_seq minvalue 1 maxvalue 999999999999 cycle;

create table api_errors
(
  error_id                          varchar2(11) primary key,
  error_timestamp                   timestamp default systimestamp at time zone 'utc' not null,
  session_id                        varchar2(32),                           -- Doesn't have to reference parent table. This allows us to catch bogus session-ids properly.
  error_code                        number(6) not null,
  error_message                     varchar2(4000),
  json_parameters                   clob
    constraint api_errors_json_parms_chk check (json_parameters is json),
  service_id                        number(12) not null
    references db_twig_services(service_id)
);

@$HOME/asterion/oracle/dbTwig/errorLogger/dba/error_logger.sql
@$HOME/asterion/oracle/dbTwig/errorLogger/dba/error_logger.pls

grant execute on &elog_user..error_logger to &dbtwig_user;

exit;
