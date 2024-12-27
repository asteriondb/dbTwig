create or replace
package dbtwig_example as

  procedure create_dbtwig_example_service;

  procedure edit_spreadsheet
  (
    p_json_parameters                 json_object_t
  );

/*

  This function is called by SELECT statement within the package body. Therefore, it has to be declared in the package header.

*/

  function generate_object_weblink
  (
    l_object_id                       varchar2
  )
  return clob;

/*

  This function is called by DbTwig on behalf of the DbTwig Example Web Application. All functions and procedures that are called
  by DbTwig have the same signature. Functions accept a JSON string of parameters and return JSON data using CLOB variables.
  Procedures accept a JSON string of parameters using a CLOB variable.

*/

  function get_maintenance_manual_detail
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  This function is called by SELECT statement within the package body. Therefore, it has to be declared in the package header.

*/

  function get_major_assembly_photos
  (
    p_manual_id                       maintenance_manuals.manual_id%type
  )
  return clob;

/*

  This function is called by DbTwig on behalf of the DbTwig Example Web Application.

*/

  function get_maintenance_manuals
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  This procedure shows you how you can accept a value from your UI and insert that into the DB. Nothing too fancy here.

*/

  procedure save_tech_note
  (
    p_json_parameters                 json_object_t
  );

/*

 This is just a placeholder procedure in order to satisfy DbTwig's requirements for a session_validation_procedure.

*/

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  );

end dbtwig_example;
.
/
show errors package dbtwig_example
