rem  Copyright (c) 2019, 2026 By AsterionDB Inc.
rem
rem  install.sql 	AsterionDB Database Vault v1.0
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script drives the creation of all required objects for the AsterionDB Converged Computing Platform.
rem
rem  Invocation:
rem
rem  sqlplus /nolog @install $DBA_USER $DBA_PASSWORD $DATABASE_NAME $DBTWIG_USER $ELOG_USER $ICAM_USER $EMAIL_USER
rem
rem
rem  NOTE: In order to maintain compatiblity w/ Oracle v19, we do not use the JSON data-type. All JSON objects are stored as clobs w/ an appropriate check constraint.
rem

whenever sqlerror exit failure;

set verify off
spool $HOME/asterion/oracle/dbTwig/email/dba/install.log

define dba_user = '&1'
define dba_password = '&2'
define database_name = '&3'
define dbtwig_user = '&4'
define elog_user = '&5'
define icam_user = '&6'
define email_user = '&7'

connect &dba_user/"&dba_password"@"&database_name";

set termout off
set echo on

@$HOME/asterion/oracle/dbTwig/email/dba/setupSchema

create synonym &email_user..db_twig for &dbtwig_user..db_twig;
grant execute on &dbtwig_user..db_twig to &email_user;

grant execute on &icam_user..icam to &email_user;
create or replace synonym &email_user..icam for &icam_user..icam;

grant references(user_id) on &icam_user..icam_users to &email_user;
create or replace synonym &email_user..icam_users for &icam_user..icam_users;
grant read on &icam_user..icam_users to &email_user;

grant references(plugin_module) on &dbtwig_user..plugin_modules to &email_user;
create or replace synonym &email_user..plugin_modules for &dbtwig_user..plugin_modules;
grant read on &dbtwig_user..plugin_modules to &email_user;

create or replace synonym &email_user..dbplugin_api for &dbtwig_user..dbplugin_api;
grant execute on &dbtwig_user..dbplugin_api to &email_user;

grant references(plugin_module) on &dbtwig_user..plugin_modules to &email_user;
create or replace synonym &email_user..plugin_modules for &dbtwig_user..plugin_modules;
grant read on &dbtwig_user..plugin_modules to &email_user;

alter session set current_schema = &email_user;

create sequence id_seq minvalue 1 maxvalue 999999999999 cycle;

create table email_configuration
(
  smtp_enabled                      varchar2(1) default 'N' not null
    constraint smtp_enabled_chk check (smtp_enabled in ('Y', 'N')),  
  smtp_email_sender                 varchar2(128),
  smtp_configuration                clob default '{}' not null
    constraint smtp_config_chk check (smtp_configuration is json),
  debug_smtp                        varchar2(1) default 'N' not null
    constraint debug_smtp_chk check (debug_smtp in ('N', 'Y'))
);

insert into email_configuration (smtp_enabled) values ('N');
commit;

create table outbound_email_log
(
  email_id                          number(12) primary key,
  date_sent                         timestamp default systimestamp at time zone 'utc' not null,
  sender_email                      varchar2(60) not null,
  recipient_data                    clob not null
    constraint recipient_data_chk check (recipient_data is json),
  subject                           varchar2(128)
);

@$HOME/asterion/oracle/dbTwig/dba/middleTierMap.sql

grant select on middle_tier_map to &dbtwig_user;

@$HOME/asterion/oracle/dbTwig/email/dba/dbTwigData

@$HOME/asterion/oracle/dbTwig/email/dba/loadPackages.sql

begin

  db_twig.create_dbtwig_service(p_service_name => email.SERVICE_NAME, p_service_owner => '&email_user', 
      p_session_validation_procedure => 'restapi.validate_session');

end;
.
/

commit;

grant execute on restapi to &dbtwig_user;

create or replace synonym &icam_user..email for &email_user..email;
grant execute on &email_user..email to &icam_user;

spool off
exit;
