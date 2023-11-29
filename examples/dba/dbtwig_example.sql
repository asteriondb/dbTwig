create or replace
package dbtwig_example as

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

  function restapi_error

  This function is registered with DbTwig when the dbTwigExample service is created. It is called when the
  DbTwig logic (in the database) detects an exception upon calling a mapped middle-tier entry-point.

  All error information is to be accessed by calling utl_call_stack.

  The returned json object shall contain an key/value pair for 'errorId' The errorId, if not null, will
  be concatenated by the DbTwig logic to form a string that says:

    'Please reference error ID ... when contacting support.'

*/

  function restapi_error
  (
    p_json_parameters                 clob              -- The JSON parameters associated with the HTTP request.
  )
  return json_object_t;

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
    p_entry_point                     middle_tier_map.entry_point%type,
    p_json_parameters                 json_object_t
  );

end dbtwig_example;
.
/
show errors package dbtwig_example
