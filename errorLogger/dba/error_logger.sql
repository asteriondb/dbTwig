create or replace
package error_logger as

/*

Copyright 2014 - 2019 by Asterion DB, LLC.

All rights reserved.

*/
  function get_api_error_log
  (
    p_service_id                      api_errors.service_id%type
  )
  return clob;

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
