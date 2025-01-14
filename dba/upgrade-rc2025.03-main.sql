/*



*/

define dba_user = '&1'
define dba_password = '&2'
define database_name = '&3'
define dbtwig_user = '&4'
define elog_user = '&5'

spool $HOME/asterion/oracle/dbTwig/dba/upgrade-rc2025.03-main.log
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

alter table dbtwig_profile add elog_service_owner varchar2(128);
alter table dbtwig_profile add api_error_handler varchar2(256);

update  dbtwig_profile
   set  elog_service_owner = '&elog_user',
        api_error_handler = 'error_logger.restapi_error';
        
alter table dbtwig_profile modify elog_service_owner not null;
alter table dbtwig_profile modify api_error_handler not null;

alter table db_twig_services drop column api_error_handler;

grant execute on dbms_crypto to &dbtwig_user;

alter table db_twig_services add jwt_signing_key varchar2(64) unique;

update  db_twig_services
   set  jwt_signing_key = dbms_crypto.randombytes(32);

commit;

alter table db_twig_services modify jwt_signing_key not null;
alter table db_twig_services add jwt_expires_in varchar2(30) default '7d' not null;

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
