create or replace
package db_twig as

/*

There are two ways to call services using DbTwig:

  1 - Use an HTTP based interface (i.e. a web browser)
  2 - Use a PL/SQL based interface with an API Key

When using the HTTP based interface, the following parameters must be embedded within the JSON parameter string:

  sessionId                   The sessionID of the restAPI client
  clientAddress               The IP address of the restAPI client
  userAgent                   The restAPI client's user-agent

Here is an example of a basic JSON parameter string:

  {"sessionId":"9YAZOHVGXQ0MFKCXYJWJZT5X61Z5O8LL", "clientAddress":"127.0.0.1", "userAgent":"..."}

When using a PL/SQL based interface, the following parameter must be embeded within the JSON parameter string:

  sessionId                   The API Key (token) granted to the caller

  {"sessionId":"J3A9DKDKJGDGKDKADFWJZASG9334O8LD"}

JSON value keys are case sensitive.

Exception Handling:
-----------------------------------------------------------------------------------------------------------------------------------
Functions and procedures may return an exception upon detecting an error.  It is the caller's responsibility to handle the
exception in accordance to the expectations of the client.  While some clients may be able to process the exception directly, others
will expect an HTTP conformant error.

The error code value associated with the exception may be Oracle specific or AsterionDB specific.  Valid AsterionDB error code
values are between -20000 and -20999.

AsterionDB specific errors are raised and logged directly by the data-layer logic.  Oracle specific errors are not caught by
data layer logic.  For Oracle specific errors it is the caller's responsibility to call restapi.restapi_error in
order to log the error information to the AsterionDB error log. The data returned by restapi_error will contain a properly
formatted error message.

There is a setting in the AsterionDB profile that enables extended error information. Enabling this option is very useful in
development and debugging situations.

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
