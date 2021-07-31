create sequence twig_demo_sequence minvalue 1 maxvalue 999999 cycle start with 1;

create table insurance_claims     
(claim_id 			                    number(6) primary key,
 insured_party 		                    varchar2(60),
 accident_date 		                    date,
 deductible_amount 		                number(8,2),
 accident_location       	            varchar2(128),
 claims_adjuster_report 	            varchar2(128)
);

create table insurance_claim_photos
(claim_id 		                        number(6)
   references insurance_claims(claim_id),
 filename 		                        varchar2(128)
);

begin

  insert into insurance_claims
    (claim_id, insured_party, accident_location, accident_date, deductible_amount, claims_adjuster_report)
  values
    (twig_demo_sequence.nextval, 'Vincent Van Gogh', 'Auvers-sur-Oise, France', '27-JUL-1890', 9239.29, 'assets/tutorials/basicIntro/pdfs/vanGogh.pdf');

  insert into insurance_claims
    (claim_id, insured_party, accident_location, accident_date, deductible_amount, claims_adjuster_report)
  values
    (twig_demo_sequence.nextval, 'James Dean', 'Cholame, California', '30-SEP-1955', 5553.12, 'assets/tutorials/basicIntro/pdfs/jamesDean.pdf');

  insert into insurance_claim_photos
    select  claim_id, 'assets/tutorials/basicIntro/images/vincentVanGogh_1.jpg'
      from  insurance_claims
     where  insured_party = 'Vincent Van Gogh';

  insert into insurance_claim_photos
    select  claim_id, 'assets/tutorials/basicIntro/images/vincentVanGogh_2.jpg'
      from  insurance_claims
     where  insured_party = 'Vincent Van Gogh';

  insert into insurance_claim_photos
    select  claim_id, 'assets/tutorials/basicIntro/images/jamesDean_1.jpg'
      from  insurance_claims
     where  insured_party = 'James Dean';

  insert into insurance_claim_photos
    select  claim_id, 'assets/tutorials/basicIntro/images/jamesDean_2.jpg'
      from  insurance_claims
     where  insured_party = 'James Dean';

end;
.
/

commit;

@@db_twig_demo
@@db_twig_demo.pls

insert into middle_tier_map values ('getInsuranceClaims', 'function', 'db_twig_demo.get_insurance_claims');
insert into middle_tier_map values ('getInsuranceClaimDetail', 'function', 'db_twig_demo.get_insurance_claim_detail');
insert into middle_tier_map values ('restApiError', 'function', 'db_twig_demo.error_handler');

commit;
