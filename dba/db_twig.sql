create or replace
package db_twig as

  SERVICE_NAME                        constant varchar2(6) := 'dbTwig';
  SECONDS_PER_DAY                     constant pls_integer := 86400;

-- Error codes -20000 through -20099 are reserved for use by DbTwig
-- Error codes -20001 through

  GENERIC_ERROR                       constant pls_integer := -20000;

  DBTWIG_FATAL_ERROR_CEILING          constant pls_integer := -20001;

  INVALID_SESSION_STATUS              constant pls_integer := -20001;                       -- This value is tied to the DbTwig middle-tier component
  INVALID_SESSION_STATUS_EMSG         constant varchar2(44) := 'An unexpected session status was encountered';

  SESSION_TIMEOUT                     constant pls_integer := -20002;                       -- This value is tied to the DbTwig middle-tier component
  SESSION_TIMEOUT_EMSG                constant varchar2(26) := 'This session has timed out';

  ACTIVE_USER_SESSION                 constant pls_integer := -20003;
  ACTIVE_USER_SESSION_EMSG            constant varchar2(40) := 'There is an active session for this user';

  INVALID_SESSION_ID                  constant pls_integer := -20004;
  INVALID_SESSION_ID_EMSG             constant varchar2(25) := 'The session ID is invalid';

  NOT_A_SITE_ADMIN                    constant pls_integer := -20005;
  NOT_A_SITE_ADMIN_EMSG               constant varchar2(48) := 'Privileged call made by a non site-administrator';

  SESSION_IP_MISMATCH                 constant pls_integer := -20006;
  SESSION_IP_MISMATCH_EMSG            constant varchar2(33) := 'Session IP addresses do not match';

  SESSION_USER_AGENT_MISMATCH         constant pls_integer := -20007;
  SESSION_USER_AGENT_MISMATCH_EMSG    constant varchar2(32) := 'Session user-agents do not match';

  DBTWIG_FATAL_ERROR_FLOOR            constant pls_integer := -20007;

  ACTION_DISALLOWED                   constant pls_integer := -20085;
  ACTION_DISALLOWED_EMSG              constant varchar2(35) := 'The requested action is not allowed';

  INVALID_CONFIRMATION_DATA           constant pls_integer := -20086;     -- Tied to JavaScript application.  Do not change value.
  INVALID_CONFIRMATION_DATA_EMSG      constant varchar2(34) := 'The confirmation data is not valid';

  EMAIL_ADDRESS_EXISTS                constant pls_integer := -20087;     -- Tied to JavaScript application.  Do not change value.
  EMAIL_ADDRESS_EXISTS_EMSG           constant varchar2(45) := 'The email address has already been registered';

  USERNAME_TAKEN                      constant pls_integer := -20088;     -- Tied to JavaScript application.  Do not change value.
  USERNAME_TAKEN_EMSG                 constant varchar2(36) := 'This username has already been taken';

  INVALID_EMAIL_ADDRESS               constant pls_integer := -200089;
  INVALID_EMAIL_ADDRESS_EMSG          constant varchar2(39) := 'The email address is invalid or unknown';

  NEW_OLD_PASSWORDS_MATCH             constant pls_integer := -200090;
  NEW_OLD_PASSWORDS_MATCH_EMSG        constant varchar2(35) := 'The new and the old passwords match';

  CHANGE_PASSWORD_FAILED              constant pls_integer := -200091;
  CHANGE_PASSWORD_FAILED_EMSG         constant varchar2(44) := 'You did not enter your password in correctly';

  UNABLE_TO_TERMINATE                 constant pls_integer := -20092;
  UNABLE_TO_TERMINATE_EMSG            constant varchar2(29) := 'Unable to terminate a session';

  UNBLOCK_SESSION_FAILED              constant pls_integer := -20093;
  UNBLOCK_SESSION_FAILED_EMSG         constant varchar2(30) := 'Unblocking of a session failed';

  USER_OR_PASSWORD                    constant pls_integer := -20094;
  USER_OR_PASSWORD_EMSG               constant varchar2(35) := 'The username or password is invalid';

  ACCOUNT_STATUS                      constant pls_integer := -20095;
  ACCOUNT_STATUS_EMSG                 constant varchar2(25) := 'Invalid account status - ';

  PASSWORD_REQUIRED                   constant pls_integer := -20096;
  PASSWORD_REQUIRED_EMSG              constant varchar2(28) := 'A password value is required';

  OWNER_ALREADY_EXISTS                constant pls_integer := -20097;
  OWNER_ALREADY_EXISTS_EMSG           constant varchar2(58) := 'The owner of this installation has already been registered';

  INVALID_INVITATION_TOKEN            constant pls_integer := -20098;
  INVALID_INVITATION_TOKEN_EMSG       constant varchar2(55) := 'The invitation link is either invalid or it has expired';

  INVALID_PARAMETERS                  constant pls_integer := -20099;
  INVALID_PARAMETERS_EMSG             constant varchar2(19) := 'Invalid parameters.';

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

The functions allow you to easily handle required parameters, parameters w/ a default value and parameters that are null if not present.

To specify a required parameter, set p_required to TRUE (default) and omit the p_default_value parameter.

To specify an optional parameter with a default value, set p_required to FALSE and provide a value for p_default_value.

To specify an optional parameter w/ a default value of null, set p_required to FALSE and omit the p_default_value parameter.

*/

  function get_array
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   json_array_t default null
  )
  return json_array_t;

  function get_boolean
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   boolean default null
  )
  return boolean;

  function get_clob
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   clob default null
  )
  return clob;

  function get_dbtwig_errors return clob;

  function get_number
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   number default null
  )
  return number;

  function get_object
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

  function get_string
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required                        boolean default true,
    p_default_value                   varchar2 default null
  )
  return varchar2;

  procedure set_log_all_requests
  (
    p_service_name                    db_twig_services.service_name%type,
    p_log_all_requests                db_twig_services.log_all_requests%type
  );

end db_twig;
.
/
show errors package db_twig
