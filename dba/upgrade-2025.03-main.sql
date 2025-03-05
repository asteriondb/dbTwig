/*



*/

define dba_user = '&1'
define dba_password = '&2'
define database_name = '&3'
define dbtwig_user = '&4'
define elog_user = '&5'

spool $HOME/asterion/oracle/dbTwig/dba/upgrade-2025.03-main.log
whenever sqlerror exit

connect &dba_user/"&dba_password"@"&database_name"

set echo on

alter session set current_schema = &dbtwig_user;
whenever sqlerror continue

REM  Put stuff between here.....

create sequence id_seq minvalue 1 maxvalue 999999999999 cycle;

alter table db_twig_services rename column service_name to old_service_name;
alter table db_twig_services add service_name varchar2(128) unique;

update  db_twig_services
   set  service_name = old_service_name;

alter table db_twig_services modify service_name not null;
alter table db_twig_services add service_id number(12);

update  db_twig_services
   set  service_id = id_seq.nextval;

commit;

alter table db_twig_services drop column old_service_name;
alter table db_twig_services modify service_id primary key;

alter table db_twig_services add service_enabled varchar2(1) default 'Y' not null
  constraint service_enabled_chk check (service_enabled in ('Y', 'N'));

alter table db_twig_services drop column api_error_handler;

create table db_twig_profile
(
  production_mode                   varchar2(1) default 'Y'
   constraint dbtwig_prod_mode_chk check (production_mode in ('Y', 'N')) not null,
  api_error_handler                 varchar2(256) not null
);

delete from db_twig_profile;

insert into db_twig_profile
  (production_mode, api_error_handler)
values
  ('Y', '&elog_user'||'.error_logger.restapi_error');
        
revoke execute on dbms_crypto from &dbtwig_user;

update  db_twig_services
   set  service_name = 'dgBunker'
 where  service_name = 'asterionDB';

commit;

REM  ...and here

@$HOME/asterion/oracle/dbTwig/dba/db_twig
@$HOME/asterion/oracle/dbTwig/dba/db_twig.pls

@$HOME/asterion/oracle/dbTwig/dba/call_restapi
@$HOME/asterion/oracle/dbTwig/dba/get_column_length

prompt 
spool off;

exit;
