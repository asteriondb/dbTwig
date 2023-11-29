rem  Copyright (c) 2019 By AsterionDB Inc.
rem
rem  install.sql 	AsterionDB DbTwig Middle Tier Framework
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script drives the creation of the DbTwig Examples.
rem
rem  Invocation: sqlplus /nolog @install
rem

whenever sqlerror exit failure;

set verify off
spool install.log

PROMPT To proceed, you will have to connect to the database as a DBA.
PROMPT

accept dba_user prompt "Enter a user name that can connect to the database as a DBA: "
accept dba_pass prompt "Enter the DBA password: " hide

connect &&dba_user/&&dba_pass;

prompt
accept dbtwig_user prompt "Enter the name of the user that owns the DbTwig schema [dbtwig]: " default dbtwig
prompt

prompt
prompt We need to create a user to own the DbTwig Example schema
accept tutorials_user prompt "Enter the name of the DbTwig Example schema owner [dbtwig_example]: " default dbtwig_example
prompt

prompt
accept tutorials_password prompt "Enter a password for the DbTwig Example schema owner: " hide
prompt

prompt
accept vault_user prompt "Enter the name of the user that owns the AsterionDB schema [asteriondb_dgbunker]: " default asteriondb_dgbunker
prompt

set echo on

rem
rem  Note how we are granting privileges to the DbTwig Example schema.  In a 
rem  production environment you would not be granting all of these privileges 
rem  (normally).  As discussed in the DbTwig documentation, in a production 
rem  environment the actual schema owners can not connect to the database and
rem  have very few, if any, privileges granted to them.  But here, you are  
rem  going to be doing development work.  Therefore, you will need to connect 
rem  to the database as a regular developer would.
rem

declare

    l_sql_text                        clob;
    l_default_tablespace              database_properties.property_value%type;

begin

    select  property_value
      into  l_default_tablespace
      from  database_properties 
     where  property_name = 'DEFAULT_PERMANENT_TABLESPACE';

    l_sql_text := 'create user &&tutorials_user identified by "&&tutorials_password"';
    execute immediate l_sql_text;

    l_sql_text := 'grant create session, create table, create procedure to &&tutorials_user';
    execute immediate l_sql_text;

    l_sql_text := 'alter user &&tutorials_user quota 50M on '||l_default_tablespace;
    execute immediate l_sql_text;

end;
.
/

rem
rem  Setup the DbTwig Example user so that it can make calls to the AsterionDB 
rem  API by using DbTwig.
rem

grant execute on &&dbtwig_user..db_twig to &&tutorials_user;

create synonym &&tutorials_user..db_twig for &&dbtwig_user..db_twig;

alter session set current_schema = &&dbtwig_user;

rem
rem  Setup DbTwig so that it knows about the dbTwigExample service.
rem

delete  from db_twig_services
 where  service_name = 'dbTwigExample';

insert into db_twig_services 
  (service_name, service_owner, replace_error_stack, session_validation_procedure, api_error_handler) 
values ('dbTwigExample', '&&tutorials_user', 'Y', 'dbtwig_example.validate_session', 'dbtwig_example.restapi_error');

alter session set current_schema = &&tutorials_user;

rem
rem  Create the middle-tier map.
rem

@@../../dba/middleTierMap

rem
rem  Insert our middle-tier map entries.
rem

@@dbTwigData

commit;

create table maintenance_manuals
(manual_id 			                number(6) primary key,
 manufacturer 		                varchar2(60),
 in_service_from	                date,
 revision_number                    number(8),
 maintenance_division    	        varchar2(128),
 maintenance_manual_filename        varchar2(128)),
 spreadsheet_id                     varchar2(32);

create table major_assembly_photos
(manual_id		                    number(6)
   references maintenance_manuals(manual_id),
 filename 		                    varchar2(128));

create table technician_notes
(manual_id                          number(6)
   references maintenance_manuals(manual_id),
 tech_note                          varchar2(256));

create sequence tutorials_seq minvalue 1 maxvalue 999999 cycle start with 1;

begin

  insert into maintenance_manuals
    (manual_id, manufacturer, maintenance_division, in_service_from, revision_number, maintenance_manual_filename)
  values
    (tutorials_seq.nextval, 'General Electric', 'Compressor Servicing', '27-JUL-2010', 100, 'assets/pdfs/compressor.pdf');

  insert into maintenance_manuals
    (manual_id, manufacturer, maintenance_division, in_service_from, revision_number, maintenance_manual_filename)
  values
    (tutorials_seq.nextval, 'Teledyne', 'Turbine Servicing', '30-SEP-2012', 22, 'assets/pdfs/turbine.pdf');

  insert into major_assembly_photos
    select  manual_id, 'assets/images/compressor_1.jpg'
      from  maintenance_manuals
     where  manufacturer = 'General Electric';

  insert into major_assembly_photos
    select  manual_id, 'assets/images/compressor_2.jpg'
      from  maintenance_manuals
     where  manufacturer = 'General Electric';

  insert into major_assembly_photos
    select  manual_id, 'assets/images/turbine_1.jpg'
      from  maintenance_manuals
     where  manufacturer = 'Teledyne';

  insert into major_assembly_photos
    select  manual_id, 'assets/images/turbine_2.jpg'
      from  maintenance_manuals
     where  manufacturer = 'Teledyne';

end;
.
/

commit;

@dbtwig_example
@dbtwig_example.pls

rem
rem  Allow DbTwig to lookup our middle-tier map entries and execute our package.
rem

grant select on middle_tier_map to &&dbtwig_user;
grant execute on dbtwig_example to &&dbtwig_user;

spool off;
exit;

