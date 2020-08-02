create or replace package body tutorials as

  function get_insurance_claim_detail
  (
    p_json_parameters                 clob
  )
  return clob

  as

    l_json_object                     json_object_t := json_object_t(p_json_parameters);
    l_claim_id                        insurance_claims.claim_id%type;
    l_clob                            clob;

  begin

    l_claim_id := l_json_object.get_number('claimId');

    select  json_object(
              'insuredParty' is insured_party,
              'accidentDate' is to_char(accident_date, 'dd-MON-yyyy'),
              'accidentLocation' is accident_location,
              'deductibleAmount' is deductible_amount,
              'claimsAdjusterReport' is claims_adjuster_report,
              'claimPhotos' is get_insurance_claim_photos(l_claim_id) format json
              returning clob)
      into  l_clob
      from  insurance_claims
     where  claim_id = l_claim_id;

    return l_clob;

  end get_insurance_claim_detail;

  function get_insurance_claim_photos
  (
    p_claim_id                        insurance_claims.claim_id%type
  )
  return clob

  as

    l_clob                            clob;

  begin

    select  json_arrayagg(json_object(
              'mediaUrl' is filename)
              returning clob)
      into  l_clob
      from  insurance_claim_photos
     where  claim_id = p_claim_id;

    return l_clob;

  end get_insurance_claim_photos;

  function get_insurance_claims 
  (
    p_json_parameters	              clob
  )
  return clob

  as

    l_clob                            clob;

  begin

    select  json_arrayagg(json_object(
              'insuredParty' is insured_party,
              'claimId' is claim_id,
              'accidentDate' is to_char(accident_date, 'dd-MON-yyyy'))
              order by insured_party returning clob)
      into  l_clob
      from  insurance_claims;

    return l_clob;

  end get_insurance_claims;

  procedure grant_execute_access
  (
    p_username                        user_users.username%type
  )
  
  is
  
  begin
  
    execute immediate 'grant execute on tutorials to '||p_username;
    
  end grant_execute_access;

end tutorials;
.
/

show errors package body tutorials;
