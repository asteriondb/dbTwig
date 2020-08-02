create or replace package tutorials as

  function get_insurance_claim_detail
  (
    p_json_parameters                 clob
  )
  return clob;

  function get_insurance_claim_photos
  (
    p_claim_id                        insurance_claims.claim_id%type
  )
  return clob;

  function get_insurance_claims
  (
    p_json_parameters                 clob
  )
  return clob;

  procedure grant_execute_access
  (
    p_username                        user_users.username%type
  );
  
end tutorials;
.
/

show errors package tutorials;
