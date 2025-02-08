create or replace
package error_logger as

/*

Copyright 2014 - 2025 by Asterion DB, LLC.

All rights reserved.

*/
  function get_api_error_log
  (
    p_service_id                      api_errors.service_id%type
  )
  return clob;

/*

  This function can be called by another micro-service to log an error and return the error-id from the error stack.

*/

  function log_api_error
  (
    p_json_parameters                 api_errors.json_parameters%type,
    p_service_id                      api_errors.service_id%type
  )
  return api_errors.error_id%type;

  procedure purge_api_errors
  (
    p_service_id                      api_errors.service_id%type
  );

/*

  function restapi_error

  This function is registered with DbTwig when the AsterionDB service is created. It is called when the
  DbTwig logic (in the database) detects an exception upon calling a mapped middle-tier entry-point.

  All error information is accessed by calling utl_call_stack.

  The returned json object shall contain an key/value pair for 'errorId'.

*/

  function restapi_error
  (
    p_json_parameters                 api_errors.json_parameters%type,
    p_service_id                      api_errors.service_id%type
  )
  return json_object_t;

end error_logger;
.
/
show errors package error_logger
