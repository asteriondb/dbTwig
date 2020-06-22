create or replace
package db_twig_demo as

  function error_handler
  (
    p_json_parameters                 clob
  )
  return clob;

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

end db_twig_demo;
.
/
show errors package db_twig_demo
