create or replace
package icam

as

-- Account Types

  AT_USER                             constant varchar2(4) := 'user';
  AT_ADMINISTRATOR                    constant varchar2(13) := 'administrator';

-- Account Status Values

  AS_ACTIVE                           constant varchar2(6) := 'active';
  AS_LOCKED                           constant varchar2(6) := 'locked';
  AS_UNCONFIRMED                      constant varchar2(11) := 'unconfirmed';
  AS_CHANGE_PASSWORD                  constant varchar2(15) := 'change password';

-- Authentication Methods

  AM_DISABLED                         constant varchar2(8) := 'password';
  AM_AUTH_CODE                        constant varchar2(9) := 'auth code';
  AM_LOGIN_URL                        constant varchar2(9) := 'login url';

-- Session Status

  SS_ACTIVE                           constant varchar2(6) := 'active';
  SS_SESSION_LIMIT                    constant varchar2(13) := 'session limit';
  SS_CHANGE_PASSWORD                  constant varchar2(15) := 'change password';
  SS_AUTH_CODE                        constant varchar2(9) := 'auth code';
  SS_LOGIN_URL                        constant varchar2(9) := 'login url';
  SS_TERMINATED                       constant varchar2(10) := 'terminated';

-- Session Disposition

  SD_TIMEOUT                          constant varchar2(7) := 'timeout';
  SD_LOGOUT                           constant varchar2(6) := 'logout';
  SD_CANCELED                         constant varchar2(8) := 'canceled';
  SD_ERROR                            constant varchar2(5) := 'error';

  function abandon_for_current_session
  (
    p_session_id                      icam_sessions.session_id%type,
    p_session_to_terminate            icam_sessions.session_id%type
  )
  return clob;

  function activate_blocked_session
  (
    p_blocked_session_id              icam_sessions.session_id%type,
    p_blocked_client_address          icam_sessions.client_address%type,
    p_blocked_user_agent              icam_sessions.user_agent%type
  )
  return clob;

  procedure change_password
  (
    p_user_id                         icam_users.user_id%type,
    p_client_address                  password_history.client_address%type,
    p_current_password                varchar2,
    p_new_password                    varchar2
  );

  procedure change_system_password
  (
    p_new_password                    varchar2
  );

  function confirm_new_user
  (
    p_identification                  icam_users.email_address%type,
    p_txt_password                    varchar2,
    p_client_address                  icam_sessions.client_address%type,
    p_user_agent                      icam_sessions.user_agent%type,
    p_confirmation_token              confirmation_tokens.confirmation_token%type
  )
  return clob;

-- This function is not exposed through the RestAPI which means the only way to call it is to be the DBA, which is by design.
-- Therefore, only the DBA can create an admin account in AsterionDB.

  function create_administrator_account
  (
    p_username                        icam_users.username%type,
    p_txt_password                    varchar2,
    p_client_address                  icam_sessions.client_address%type,
    p_first_name                      icam_users.first_name%type,
    p_last_name                       icam_users.last_name%type,
    p_middle_name                     icam_users.middle_name%type default null,
    p_email_address                   icam_users.email_address%type default null,
    p_default_timezone                icam_users.default_timezone%type default 'Etc/GMT'
  )
  return icam_users.user_id%type;

  procedure create_api_client_session
  (
    p_api_client_token                icam_sessions.session_id%type,
    p_old_client_token                icam_sessions.session_id%type,
    p_json_parameters                 json_object_t
  );

  function create_confirmation_token
  (
    p_user_id                         icam_users.user_id%type,
    p_purpose                         confirmation_tokens.purpose%type,
    p_expiration_date                 confirmation_tokens.expiration_date%type,
    p_client_address                  confirmation_tokens.client_address%type default null,
    p_email_address                   confirmation_tokens.email_address%type default null,
    p_session_id                      icam_sessions.session_id%type default null
  )
  return confirmation_tokens.confirmation_token%type;

  procedure create_icam_service;

  function create_user_account
  (
    p_username                        icam_users.username%type,
    p_first_name                      icam_users.first_name%type,
    p_middle_name                     icam_users.middle_name%type,
    p_last_name                       icam_users.last_name%type,
    p_email_address                   icam_users.email_address%type,
    p_default_timezone                icam_users.default_timezone%type,
    p_client_address                  icam_sessions.client_address%type,
    p_caller_session_id               icam_sessions.session_id%type
  )
  return clob;

  function create_user_session
  (
    p_identification                  varchar2,
    p_txt_password                    varchar2,
    p_client_address                  icam_sessions.client_address%type,
    p_user_agent                      icam_sessions.user_agent%type
  )
  return clob;

  function extract_email_domain
  (
    p_email_address                   icam_users.email_address%type
  )
  return varchar2 deterministic;

  function extract_session_id
  (
    p_json_object                     json_object_t
  )
  return icam_sessions.session_id%type;

  procedure generate_password_reset_token
  (
    p_email_address                   icam_users.email_address%type,
    p_client_address                  confirmation_tokens.client_address%type
  );

  function generate_temporary_password
  (
    p_session_id                      icam_sessions.session_id%type,
    p_client_address                  icam_sessions.client_address%type,
    p_username                        icam_users.username%type
  )
  return varchar2;

  function get_active_session_count return pls_integer;

  function get_active_session_count
  (
    p_user_id                         icam_users.user_id%type
  )
  return number;

  function get_active_sessions
  (
    p_user_id                         icam_users.user_id%type
  )
  return clob;

  function get_blocked_session_user_id
  (
    p_json_parameters                 json_object_t
  )
  return icam_users.user_id%type;

  function get_last_activity
  (
    p_user_id                         icam_users.user_id%type
  )
  return icam_sessions.last_activity%type;


/*

  function get_login_history

  API Entry Point: getLoginHistory

  The get_login_history function allows a user to retrieve their login history.

  Embedded parameter values:

    There are no required parameters.

  Embedded values in the returned JSON string value:

    The JSON object returned by this function contains an array of login history entries with the following properties:

      sessionCreated          A Unix timestamp value indicating the date and time that the session was created.

      clientAddress           The client's IP address.

      sessionStatus           The present status of the session.  Possible values are:

        SS_ACTIVE
        SS_SESSION_LIMIT
        SS_CHANGE_PASSWORD
        SS_TERMINATED

      sessionDisposition      The session's disposition upon termination.  Possible values are:

                                SD_TIMEOUT
                                SD_LOGOUT
                                SD_CANCELED
                                SD_ERROR

      userAgent               The user agent (browser) associated with the session.

      sessionEnded            A Unix timestamp value indicating the date and time that the session was terminated.

      lastActivity            A Unix timestamp value indicating the date and time of the last session activity.  This value is used
                              to determine if a session has timed-out.

      terminatedBy            The terminatedBy value conveys the user that terminated a session - if termination was by user
                              intervention.

*/

  function get_login_history
  (
    p_user_id                         icam_users.user_id%type
  )
  return clob;

  function get_session_info
  (
    p_session_id                      icam_sessions.session_id%type
  )
  return clob;

  function get_session_user_id
  (
    p_session_id                      icam_sessions.session_id%type
  )
  return icam_users.user_id%type;

  function get_session_user_id_from_json
  (
    p_json_object                     json_object_t
  )
  return icam_users.user_id%type;

  function get_session_user_id_from_json
  (
    p_json_parameters                 clob
  )
  return icam_users.user_id%type;

  function get_terminated_by
  (
    p_terminator_id                   icam_sessions.terminator_id%type
  )
  return icam_users.username%type;

  function get_session_username
  (
    p_session_id                      icam_sessions.session_id%type
  )
  return icam_users.username%type;

  function get_user_settings
  (
    p_user_id                         icam_users.user_id%type
  )
  return clob;

  function get_user_id
  (
    p_username                        icam_users.username%type
  )
  return icam_users.user_id%type;

  function get_user_list return clob;

  function get_user_settings
  (
    p_username                        icam_users.username%type
  )
  return clob;

  function hash_value_for_user
  (
    p_value_to_hash                   varchar2,
    p_user_id                         icam_users.user_id%type
  )
  return raw;

  function hashed_value
  (
    p_value_to_hash                   varchar2,
    p_random_bytes                    icam_users.random_bytes%type
  )
  return raw;

/*
  procedure record_login_attempt
  (
    p_supplied_username               login_history.supplied_username%type,
    p_ip4_address                     login_history.client_address%type,
    p_success_or_failure              login_history.success_or_failure%type,
    p_error_code                      login_history.error_code%type
  );
*/

  procedure recover_username
  (
    p_email_address                   icam_users.email_address%type,
    p_client_address                  confirmation_tokens.client_address%type
  );

-- This procedure is not mapped to the middle-tier. DBA access only.

  procedure remove_unconfirmed_users;

-- This procedure is not mapped to the middle-tier. DBA access only.

  procedure remove_user
  (
    p_user_id                         icam_users.user_id%type
  );

  procedure reset_password
  (
    p_confirmation_token              confirmation_tokens.confirmation_token%type,
    p_new_password                    varchar2,
    p_client_address                  password_history.client_address%type
  );

  procedure send_change_email_code
  (
    p_user_id                         icam_users.user_id%type,
    p_new_email_address               icam_users.email_address%type,
    p_client_address                  confirmation_tokens.client_address%type
  );

  procedure site_administrator_check
  (
    p_json_parameters                 json_object_t
  );

  procedure terminate_all_icam_sessions
  (
    p_user_id                         icam_users.user_id%type
  );

  procedure terminate_idle_sessions
  (
    p_terminator_id                   icam_sessions.session_id%type default null
  );

  procedure terminate_session_with_error
  (
    p_session_id                      icam_sessions.session_id%type,
    p_error_code                      pls_integer,
    p_error_message                   varchar2
  );

  procedure terminate_user_session
  (
    p_session_id                      icam_sessions.session_id%type
  );

  procedure toggle_account_status
  (
    p_username                        icam_users.username%type
  );

  procedure update_user_info
  (
    p_user_id                         icam_users.user_id%type,
    p_first_name                      icam_users.first_name%type,
    p_middle_name                     icam_users.middle_name%type,
    p_last_name                       icam_users.last_name%type
  );

  procedure update_user_preferences
  (
    p_user_id                         icam_users.user_id%type,
    p_auth_method                     icam_users.auth_method%type,
    p_default_timezone                icam_users.default_timezone%type
  );

  procedure update_user_properties
  (
    p_username                        icam_users.username%type,
    p_session_limit                   icam_users.session_limit%type,
    p_session_inactivity_limit        icam_users.session_inactivity_limit%type
  );

  procedure validate_change_email_code
  (
    p_user_id                         icam_users.user_id%type,
    p_change_email_code               confirmation_tokens.confirmation_token%type
  );

  procedure validate_confirmation_token
  (
    p_confirmation_token              confirmation_tokens.confirmation_token%type,
    p_check_only                      boolean default false
  );

  procedure validate_new_email_address
  (
    p_email_address                   icam_users.email_address%type
  );

  function validate_login_authorization
  (
    p_confirmation_token              confirmation_tokens.confirmation_token%type
  )
  return clob;

  procedure validate_new_username
  (
    p_username                        icam_users.username%type
  );

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  );

  procedure validate_session
  (
    p_entry_point                     middle_tier_map.entry_point%type,
    p_json_parameters                 json_object_t
  );

  procedure validate_session_id
  (
    p_json_parameters                 json_object_t,
    p_allow_blocked_session           varchar2,
    p_check_header_info               varchar2
  );

end icam;
.
/
show errors package icam
