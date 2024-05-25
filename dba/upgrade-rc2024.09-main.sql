/*



*/

spool $HOME/asterion/oracle/dbTwig/dba/upgrade-rc2024.09-main.log

REM  Put stuff between here.....

whenever sqlerror exit
alter session set current_schema = &1;
whenever sqlerror continue

revoke execute on &1..db_twig from &2;
drop synonym &2..db_twig;

REM  ...and here

create table dbtwig_profile
(
  production_mode                   varchar2(1) default 'Y'
   constraint prod_mode_chk check (production_mode in ('Y', 'N')) not null
);

declare

  l_production_mode                 dbtwig_profile.production_mode%type;

begin

  select  production_mode
    into  l_production_mode
    from  dbtwig_profile;

exception

when no_data_found then

  insert into dbtwig_profile values ('Y');

end;
.
/

commit;

create table logged_requests
(
  request_timestamp                 timestamp default systimestamp at time zone 'utc' not null,
  request                           clob not null
);

alter table db_twig_services rename column replace_error_stack to production_mode;
alter table db_twig_services rename constraint replace_stack_chk to svc_prod_mode_chk;
alter table db_twig_services add log_all_requests varchar2(1) default 'N'
   constraint log_all_requests_chk check (log_all_requests in ('Y', 'N')) not null;

@$HOME/asterion/oracle/dbTwig/dba/db_twig
@$HOME/asterion/oracle/dbTwig/dba/db_twig.pls

@$HOME/asterion/oracle/dbTwig/dba/call_restapi

grant execute on &1..call_restapi to &2;
create synonym &2..call_restapi for &1..call_restapi;

prompt 
spool off;

