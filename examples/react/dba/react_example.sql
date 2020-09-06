create or replace
package react_example as

  function generate_object_weblink
  (
    l_object_id                       varchar2
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

end react_example;
.
/
show errors package react_example
