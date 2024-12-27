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
rem  sqlplus /nolog @install $DBA_USER $DBA_PASSWORD $DATABASE_NAME $DBTWIG_USER $ELOG_USER $ICAM_USER
rem

whenever sqlerror exit failure;

set verify on
spool $HOME/asterion/oracle/dbTwig/icam/dba/install.log

define dba_user = '&1'
define dba_password = '&2'
define database_name = '&3'
define dbtwig_user = '&4'
define elog_user = '&5'
define icam_user = '&6'

connect &dba_user/"&dba_password"@"&database_name";

set termout off
set echo on

@$HOME/asterion/oracle/dbTwig/icam/dba/setupSchema

create or replace synonym &icam_user..db_twig for &dbtwig_user..db_twig;
create or replace synonym &icam_user..error_logger for &elog_user..error_logger;
create or replace synonym &icam_user..get_column_length for &dbtwig_user..get_column_length;

grant execute on &dbtwig_user..db_twig to &icam_user;
grant execute on &elog_user..error_logger to &icam_user;
grant execute on dbms_crypto to &icam_user;
grant execute on &dbtwig_user..get_column_length to &icam_user;

alter session set current_schema = &icam_user;

create sequence id_seq minvalue 1 maxvalue 999999999999 cycle;

create table icam_users
(
  user_id				            number(12) primary key,
  username				            varchar2(30) not null
    constraint username_chk check (0 = instr(username, '@')),
  hashed_username_password          raw(64) not null,
  random_bytes                      raw(16) not null,
  email_address				        varchar2(128) 
    constraint email_address_chk check (0 != instr(email_address, '@')),
  account_status			        varchar2(20) not null
    constraint account_status check (account_status in ('active', 'locked', 'unconfirmed', 'change password')),
  account_type				        varchar2(20)
    constraint user_account_type check (account_type in ('user', 'administrator')) not null,
  session_inactivity_limit		    number(5) default 3600 
    constraint user_inactivity_limit_chk check (session_inactivity_limit <= 86400) not null,
  first_name				        varchar2(30) not null,
  middle_name   			        varchar2(30),
  last_name				            varchar2(30) not null,
  creation_date				        timestamp default systimestamp at time zone 'utc' not null,
  session_limit                     number(2) default 1 not null,
  default_timezone                  varchar2(30) default 'Etc/GMT' not null,
  auth_method                       varchar2(9) default 'password' not null
    constraint auth_method_chk check (auth_method in ('password', 'auth code', 'login url'))
);

create unique index icam_user_ix on icam_users(upper(username));
create unique index icam_email_ix on icam_users(upper(email_address));

create table login_history
(
  login_attempt_timestamp           timestamp default systimestamp at time zone 'utc',
  supplied_identification           varchar2(128) not null,
  success_or_failure                varchar2(7) not null
    constraint lh_success_chk check (success_or_failure in ('success', 'failure')),
  client_address                	varchar2(39)
);

create table invited_users
(
  invitation_token			        varchar2(32) unique not null,
  user_sending_invitation           number(12) not null
    references icam_users(user_id),
  email_address				        varchar2(128) not null,
  first_name				        varchar2(30) not null,
  last_name				            varchar2(30) not null,
  invitation_date                   timestamp default systimestamp at time zone 'utc' not null,
  expiration_date			        timestamp not null,
  invitation_status                 varchar2(12) default 'not accepted' not null 
    constraint invitation_status_chk check (invitation_status in ('not accepted', 'accepted', 'cancelled')),
  invitation_note                   varchar2(2048)
);

create index invited_users_sending_user_id_ix on invited_users(user_sending_invitation);

create table password_history
(
  user_id				            number(12) not null
    references icam_users(user_id),
  change_made_by                    number(12)
    references icam_users(user_id),
  old_hashed_username_password      raw(64),
  replacement_date			        timestamp default systimestamp at time zone 'utc',
  replacement_method			    varchar2(128),
  client_address          			varchar2(39) not null
);

create index password_history_user_id_ix on password_history(user_id);
create index password_history_changed_by_ix on password_history(change_made_by);

create table account_status_history
(
  user_id				            number(12) not null
    references icam_users(user_id),
  prior_status				        varchar2(20) not null
    constraint status_history check (prior_status in ('active', 'locked', 'unconfirmed')),
  transition_date			        timestamp default systimestamp at time zone 'utc',
  transition_reason			        varchar2(128)
);

create index account_status_user_ix on account_status_history(user_id);

create table icam_sessions
(
  session_id				        varchar2(32) primary key,
  user_id				            number(12) not null
    references icam_users(user_id),
  client_address                	varchar2(39) not null,
  session_created			        timestamp,
  session_ended				        timestamp,
  session_status			        varchar2(15)
    constraint user_sess_status_ck check
      (session_status in ('active', 'session limit', 'change password', 'terminated', 'auth code', 'login url')) not null,
  session_disposition			    varchar2(15)
    constraint user_sess_disposition_ck check
      (session_disposition in (null, 'logout', 'timeout', 'canceled', 'error')),
  last_activity				        timestamp,
  session_inactivity_limit		    number(5) default 60 
    constraint user_sess_inactivity_limit_chk check (session_inactivity_limit <= 86400) not null,
  user_agent				        varchar2(1024) not null,
  terminator_id                     varchar2(32)
    references icam_sessions(session_id),
  client_type                       varchar2(16) not null
    constraint user_sess_client_type check (client_type in ('webAppClient', 'fileUploadClient', 'apiClient'))
);

create index icam_sessions_user_id_ix on icam_sessions(user_id);

create table confirmation_tokens
(
  confirmation_token			    varchar2(32) unique not null,
  user_id				            number(12) not null
    references icam_users(user_id),
  purpose				            varchar2(20) not null
    constraint conf_token_purpose_ck check (purpose in ('account confirmation', 'change email', 'password reset', 'auth code', 'login url')),
  creation_date				        timestamp default systimestamp at time zone 'utc',
  expiration_date			        timestamp not null,
  disposition_date			        timestamp,
  token_status				        varchar2(15) default 'unused' not null
    constraint conf_token_stat_ck check
      (token_status in ('unused', 'used', 'cancelled', 'expired')),
  client_address                    varchar2(39) not null,
  email_address                     varchar2(128),
  session_id                        varchar2(32)
    references icam_sessions(session_id)
);

create index conf_token_user_id_ix on confirmation_tokens(user_id);
create index conf_token_session_id_ix on confirmation_tokens(session_id);

@$HOME/asterion/oracle/dbTwig/dba/middleTierMap.sql
@$HOME/asterion/oracle/dbTwig/icam/dba/dbTwigData

@$HOME/asterion/oracle/dbTwig/icam/dba/loadPackages

grant select on &icam_user..middle_tier_map to &dbtwig_user;
grant execute on &icam_user..restapi to &dbtwig_user;
grant execute on &icam_user..icam to &elog_user;

create or replace synonym &elog_user..icam for &icam_user..icam;

alter package &elog_user..error_logger compile body;

begin icam.create_icam_service; end;
.
/

commit;

exit;
