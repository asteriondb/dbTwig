create or replace
package db_twig as

/*

Calling API Components via DbTwig - Required Parameters
-----------------------------------------------------------------------------------------------------------------------------------
There are two ways to call services using DbTwig:

  1 - Use an HTTP based interface (i.e. a web browser calling the HTTPS DbTwig listener)
  2 - Use a PL/SQL based interface with an API Key - for calls between services in the database

When using the HTTP based interface, the following parameters must be embedded within the p_json_parameters string:

  sessionId                   The sessionID of the restAPI client
  clientAddress               The IP address of the restAPI client
  userAgent                   The restAPI client's user-agent

Here is an example of a basic JSON parameter string:

  {"sessionId":"9YAZOHVGXQ0MFKCXYJWJZT5X61Z5O8LL", "clientAddress":"127.0.0.1", "userAgent":"..."}

When using a PL/SQL based interface, the following parameter must be embeded within the JSON parameter string:

  sessionId                   The API Key (token) granted to the caller

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
