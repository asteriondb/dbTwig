create or replace
package db_twig as

  GENERIC_ERROR                       constant pls_integer := -20100;           -- Borrowed from AsterionDB.
  SECONDS_PER_DAY                     constant pls_integer := 86400;

  function call_restapi
  (
    p_json_parameters                 clob
  )
  return clob;

  function convert_date_to_unix_timestamp
  (
    p_date_value                      date
  )
  return number;

  function convert_timestamp_to_unix_timestamp
  (
    p_timestamp_value                 timestamp
  )
  return varchar2;

  procedure convert_timestamp_to_timeval
  (
    p_timestamp_value                 timestamp,
    p_tv_sec                          out number,
    p_tv_usec                         out number
  );

  function convert_unix_timestamp_to_date
  (
    p_unix_timestamp                  number
  )
  return date;

  function convert_unix_timestamp_to_timestamp
  (
    p_unix_timestamp                  float
  )
  return timestamp;

  procedure create_dbtwig_service
  (
    p_service_owner                   db_twig_services.service_owner%type,
    p_service_name                    db_twig_services.service_name%type,
    p_session_validation_procedure    db_twig_services.session_validation_procedure%type
  );

  procedure db_twig_error
  (
    p_error_code                      db_twig_errors.error_code%type,
    p_json_parameters                 db_twig_errors.json_parameters%type default null,
    p_error_message                   db_twig_errors.error_message%type default null
  );

  function empty_json_array
  (
    p_key                             varchar2
  )
  return clob;

/*

These helper functions make it easy to extract a parameter from a JSON object.

The functions allow you to easily handle required parameters, parameters w/ a default value and parameters that are null if not present.'

To specify a required parameter, set p_required to TRUE and omit the p_default_value parameter.

To specify an optional parameter with a default value, set p_required to FALSE and provide a value for p_default_value.

To specify an optional parameter w/ a default value of null, set p__required to FALSE and omit the p_default_value parameter.

*/

  function get_array_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   json_array_t default null
  )
  return json_array_t;

  function get_clob_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   clob default null
  )
  return clob;

  function get_dbtwig_errors return clob;

  function get_number_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   number default null
  )
  return number;

  function get_object_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   json_object_t default null
  )
  return json_object_t;

  function get_service_data
  (
    p_service_name                    db_twig_services.service_name%type
  )
  return clob;

  function get_service_id
  (
    p_service_name                    db_twig_services.service_name%type
  )
  return db_twig_services.service_id%type;

  function get_string_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   varchar2 default null
  )
  return varchar2;

end db_twig;
.
/
show errors package db_twig
