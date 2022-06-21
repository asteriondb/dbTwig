create or replace
package react_example as

--  This function is called by SELECT statement within the package body.
--  Therefore, it has to be declared in the package header.

  function generate_object_weblink
  (
    l_object_id                       varchar2
  )
  return clob;

--  This function is called by DbTwig on behalf of the React Example Web
--  Application.  All functions and procedures that are called by DbTwig
--  have the same signature.  Functions accept a JSON string of parameters
--  and return JSON data using CLOB variables.  Procedures accept a JSON string
--  of parameters using a CLOB variable.

  function get_insurance_claim_detail
  (
    p_json_parameters                 json_object_t
  )
  return clob;

--  This function is called by SELECT statement within the package body.
--  Therefore, it has to be declared in the package header.

  function get_insurance_claim_photos
  (
    p_claim_id                        insurance_claims.claim_id%type
  )
  return clob;

--  This function is called by DbTwig on behalf of the React Example Web
--  Application.

  function get_insurance_claims
  (
    p_json_parameters                 json_object_t
  )
  return clob;

-- This is just a placeholder procedure in order to satisfy DbTwig's requirements
-- for a session_validation_procedure.

  procedure validate_session
  (
    p_object_type                     middle_tier_map.object_type%type,
    p_object_name                     middle_tier_map.object_name%type,
    p_json_parameters                 json_object_t
  );

end react_example;
.
/
show errors package react_example
