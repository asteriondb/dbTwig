rem  Copyright (c) 2019 By AsterionDB Inc.
rem
rem  install.sql 	AsterionDB DbTwig Middle Tier Framework
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script drives the creation of the DbTwig React Example.
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
accept tutorials_user prompt "Enter the name of the DbTwig Example schema owner [react_example]: " default react_example
prompt

prompt
accept tutorials_password prompt "Enter a password for the DbTwig Example schema owner: " hide
prompt

prompt
accept vault_user prompt "Enter the name of the user that owns the AsterionDB schema [asteriondb_objvault]: " default asteriondb_objvault
prompt

set echo on

rem
rem  Note how we are granting privileges to the React Example schema.  In a 
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
rem  Setup the React Example user so that it can make calls to the AsterionDB 
rem  API by using DbTwig.
rem

grant execute on &&dbtwig_user..db_twig to &&tutorials_user;

create synonym &&tutorials_user..db_twig for &&dbtwig_user..db_twig;

alter session set current_schema = &&dbtwig_user;

rem
rem  Setup DbTwig so that it knows about the reactExample service.
rem

insert into db_twig_services 
  (service_name, service_owner, replace_error_stack, session_validation_procedure) 
values ('reactExample', '&&tutorials_user', 'Y', 'react_example.validate_session');

alter session set current_schema = &&tutorials_user;

rem
rem  Create the middle-tier map.
rem

@@../../../dba/middleTierMap

rem
rem  Insert our middle-tier map entries.
rem

@@dbTwigData

commit;

create table insurance_claims     
(claim_id 			                number(6) primary key,
 insured_party 		                varchar2(60),
 accident_date 		                date,
 deductible_amount 		            number(8,2),
 accident_location       	        varchar2(128),
 claims_adjuster_report 	        varchar2(128));

create table insurance_claim_photos
(claim_id 		                    number(6)
   references insurance_claims(claim_id),
 filename 		                    varchar2(128));

create sequence tutorials_seq minvalue 1 maxvalue 999999 cycle start with 1;

begin

  insert into insurance_claims
    (claim_id, insured_party, accident_location, accident_date, deductible_amount, claims_adjuster_report)
  values
    (tutorials_seq.nextval, 'Vincent Van Gogh', 'Auvers-sur-Oise, France', '27-JUL-1890', 9239.29, 'assets/pdfs/vanGogh.pdf');

  insert into insurance_claims
    (claim_id, insured_party, accident_location, accident_date, deductible_amount, claims_adjuster_report)
  values
    (tutorials_seq.nextval, 'James Dean', 'Cholame, California', '30-SEP-1955', 5553.12, 'assets/pdfs/jamesDean.pdf');

  insert into insurance_claim_photos
    select  claim_id, 'assets/images/vincentVanGogh_1.jpg'
      from  insurance_claims
     where  insured_party = 'Vincent Van Gogh';

  insert into insurance_claim_photos
    select  claim_id, 'assets/images/vincentVanGogh_2.jpg'
      from  insurance_claims
     where  insured_party = 'Vincent Van Gogh';

  insert into insurance_claim_photos
    select  claim_id, 'assets/images/jamesDean_1.jpg'
      from  insurance_claims
     where  insured_party = 'James Dean';

  insert into insurance_claim_photos
    select  claim_id, 'assets/images/jamesDean_2.jpg'
      from  insurance_claims
     where  insured_party = 'James Dean';

end;
.
/

commit;

@react_example
@react_example.pls

rem
rem  Allow DbTwig to lookup our middle-tier map entries and execute our package.
rem

grant select on middle_tier_map to &&dbtwig_user;
grant execute on react_example to &&dbtwig_user;

spool off;
exit;

