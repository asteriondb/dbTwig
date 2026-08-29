/*



*/

define dbtwig_user = '&1'
define dbplugin_user = '&2'
define middle_tier_password = '&3'

spool $HOME/asterion/oracle/dbTwig/dba/upgrade-rc2026.09-main.log
whenever sqlerror exit

set echo on

alter session set current_schema = &dbtwig_user;
whenever sqlerror continue

REM  Put stuff between here.....

create table plugin_servers (
  plugin_server					    varchar2(255) primary key,
  ip_address					    varchar2(39),
  last_activity_timestamp	        timestamp,
  support_info                      clob default null
    constraint plugin_support_json_chk check (support_info is json),
  heartbeat_timestamp               timestamp not null,
  heartbeat_interval                number(3) default 60 not null);

create table plugin_modules (
  plugin_server					    varchar2(255)
    constraint plugin_module_server_fk references
    plugin_servers(plugin_server),
  plugin_module					    varchar2(30),
  driver_name					    varchar2(30) default 'dbPluginDriver',
  library_name					    varchar2(30));

create unique index plugin_module_ix on plugin_modules(plugin_server, plugin_module);

grant execute on dbms_aq to &dbtwig_user;
grant execute on dbms_aqadm to &dbtwig_user;

alter table db_twig_profile add ssl_enabled varchar2(1) default 'N' not null constraint dbtwig_ssl_enabled_chk check (ssl_enabled in ('N', 'Y'));

@$HOME/asterion/oracle/dbTwig/dba/dbPluginType
@$HOME/asterion/oracle/dbTwig/dba/createDbPluginQueue &dbtwig_user

declare

    l_sql_text                        clob;

begin

    l_sql_text := 'grant create session to &dbplugin_user identified by "&middle_tier_password"';
    execute immediate l_sql_text;

end;
.
/

@@loadPackages

create or replace synonym &dbplugin_user..dbplugin_runtime_api for &dbtwig_user..dbplugin_runtime_api;
grant execute on &dbtwig_user..dbplugin_runtime_api to &dbplugin_user;

create or replace synonym &dbtwig_user..error_logger for &elog_user..error_logger;
grant execute on &elog_user..error_logger to &dbtwig_user;

REM  ...and here

REM @@loadPackages

prompt 
spool off;

