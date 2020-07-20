rem  Copyright (c) 2019 By AsterionDB Inc.
rem
rem  install.sql 	AsterionDB DbTwig Middle Tier Framework
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script drives the creation of all required objects for the DbTwig Middle Tier Framework
rem  suite of tutorials.
rem
rem  Invocation: sqlplus /nolog @install $DBA_USER $DBA_PASSWORD $DATABASE_NAME $DBTWIG_USER $DBTWIG_TUTORIALS_USER $DBTWIG_TUTORIALS_PASSWORD $VAULT_USER

whenever sqlerror exit failure;

set verify off
spool install.log

connect &1/"&2"@"&3";

set echo on

declare

    l_sql_text                        clob;
    l_default_tablespace              database_properties.property_value%type;

begin

    select  property_value
      into  l_default_tablespace
      from  database_properties 
     where  property_name = 'DEFAULT_PERMANENT_TABLESPACE';

    l_sql_text := 'create user &5 identified by "&6"';
    execute immediate l_sql_text;

    l_sql_text := 'grant create session, create table, create procedure to &5';
    execute immediate l_sql_text;

    l_sql_text := 'alter user &5 quota 50M on '||l_default_tablespace;
    execute immediate l_sql_text;

end;
.
/

alter session set current_schema = &4;

insert into db_twig_services values ('asterionDBTutorials', '&5');

alter session set current_schema = &5;

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

@@tutorials
@@tutorials.pls

@@../../dba/middleTierMap

insert into middle_tier_map values ('getInsuranceClaims', 'function', 'tutorials.get_insurance_claims');
insert into middle_tier_map values ('getInsuranceClaimDetail', 'function', 'tutorials.get_insurance_claim_detail');
insert into middle_tier_map values ('restApiError', 'function', 'tutorials.error_handler');

commit;

spool off;
exit;

