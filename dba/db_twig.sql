create or replace
package db_twig as

/*

Calling API Components via DbTwig - Required Parameters
-----------------------------------------------------------------------------------------------------------------------------------
There are two ways to call services using DbTwig:

  1 - Use an HTTP based interface (i.e. a web browser calling the HTTPS DbTwig listener)
  2 - Use a PL/SQL based interface with an API Key - for calls between services in the database

When using the HTTP based interface, the session-id is specified in the 'authorization' request header field as a
'Bearer Authorization' token (e.g. Bearer 9YAZOHVGXQ0MFKCXYJWJZT5X61Z5O8LL). You will need to include this header field when you
build your HTTP request.

When using a PL/SQL based interface, the session-id is embeded within the JSON parameter string:

  {"sessionId":"J3A9DKDKJGDGKDKADFWJZASG9334O8LD"}

JSON value keys are case sensitive.

Session Validation
-----------------------------------------------------------------------------------------------------------------------------------
The DbTwig middle-tier logic performs session validation by calling the session validation procedure for a registered service
(i.e. db_twig_services.session_validation_procedure). It is the responsibility of the service's session validation procedcure to
perform any required checks and validations.

The signature of a session validation procedure is:

  procedure validate_session
  (
    p_entry_point                     middle_tier_map.entry_point%type,
    p_json_parameters                 json_object_t
  );

Note - You do not have to use the same procedure name as shown above.

Exception Handling
-----------------------------------------------------------------------------------------------------------------------------------
The call_rest_api function will catch any exceptions thrown by the called API component. Upon catching an exception, DbTwig will
call the error handler (i.e. db_twig_services.api_error_handler) registered for the service. It is the responsibility of the
error handler to perform any logic required and return an 'error-id' string in a JSON object.

The signature of the error handler function is:

  function restapi_error
  (
    p_json_parameters                 api_errors.json_parameters%type
  )
  return json_object_t;

Note - You do not have to use the same function name as shown above.

*/

  function call_rest_api
  (
    p_json_parameters                 clob
  )
  return clob;

end db_twig;
.
/
show errors package db_twig
