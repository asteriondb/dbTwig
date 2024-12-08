create or replace
package body restapi

as

  function abandon_for_current_session
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_session_to_terminate            icam_sessions.session_id%type;
    l_session_id                      icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);

  begin

    l_session_to_terminate := db_twig.get_string_parameter(p_json_parameters, 'sessionToTerminate');

    return icam.abandon_for_current_session(l_session_id, l_session_to_terminate);

  end abandon_for_current_session;

  function activate_blocked_session
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_blocked_session_id              icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);
    l_blocked_client_address          icam_sessions.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');
    l_blocked_user_agent              icam_sessions.user_agent%type := db_twig.get_string_parameter(p_json_parameters, 'userAgent');

  begin

    return icam.activate_blocked_session(l_blocked_session_id, l_blocked_client_address, l_blocked_user_agent);

  end activate_blocked_session;

  function change_password
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_session_status                  icam_sessions.session_status%type;

    l_session_id                      icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);
    l_client_address                  icam_sessions.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');
    l_current_password                varchar2(60);
    l_new_password                    varchar2(60);
    l_clob                            clob;

    l_blocked_session_id              icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);
    l_blocked_user_agent              icam_sessions.user_agent%type := db_twig.get_string_parameter(p_json_parameters, 'userAgent');


  begin

    l_current_password := db_twig.get_string_parameter(p_json_parameters, 'currentPassword');
    l_new_password := db_twig.get_string_parameter(p_json_parameters, 'newPassword');
    icam.change_password(icam.get_session_user_id_from_json(p_json_parameters),
      l_client_address, l_current_password, l_new_password);

    select  session_status
      into  l_session_status
      from  icam_sessions
     where  session_id = l_session_id;

    if icam.SS_CHANGE_PASSWORD = l_session_status then

      return icam.activate_blocked_session(l_blocked_session_id, l_client_address, l_blocked_user_agent);

    end if;

    select  json_object('sessionStatus' is l_session_status)
      into  l_clob
      from  dual;

    return l_clob;

  end change_password;

  procedure check_confirmation_token
  (
    p_json_parameters                 json_object_t
  )

  is

    l_confirmation_token              confirmation_tokens.confirmation_token%type;

  begin

    l_confirmation_token := db_twig.get_string_parameter(p_json_parameters, 'confirmationToken');
    icam.validate_confirmation_token(p_confirmation_token => l_confirmation_token, p_check_only => true);

  end check_confirmation_token;

  function create_user_account
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_username                        icam_users.username%type;
    l_first_name                      icam_users.first_name%type;
    l_middle_name                     icam_users.middle_name%type;
    l_last_name                       icam_users.last_name%type;
    l_email_address                   icam_users.email_address%type;
    l_default_timezone                icam_users.default_timezone%type;
    l_caller_session_id               icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);
    l_client_address                  icam_sessions.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');

  begin

    l_username := db_twig.get_string_parameter(p_json_parameters, 'username');
    l_first_name := db_twig.get_string_parameter(p_json_parameters, 'firstName');
    l_middle_name := db_twig.get_string_parameter(p_json_parameters, 'middleName', false);
    l_last_name := db_twig.get_string_parameter(p_json_parameters, 'lastName');
    l_email_address := db_twig.get_string_parameter(p_json_parameters, 'emailAddress');
    l_default_timezone := db_twig.get_string_parameter(p_json_parameters, 'defaultTimezone', false, 'Etc/GMT');

    return icam.create_user_account(l_username, l_first_name, l_middle_name, l_last_name, l_email_address, l_default_timezone,
      l_client_address, l_caller_session_id);

  end create_user_account;

  function create_user_session
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_client_address                  icam_sessions.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');
    l_user_agent                      icam_sessions.user_agent%type;
    l_clob                            clob;
    l_identification                  icam_users.username%type;
    l_txt_password                    varchar2(60);

  begin

    l_user_agent := db_twig.get_string_parameter(p_json_parameters, 'userAgent');
    l_identification := db_twig.get_string_parameter(p_json_parameters, 'identification');
    l_txt_password := db_twig.get_string_parameter(p_json_parameters, 'password');
    l_clob := icam.create_user_session(l_identification, l_txt_password, l_client_address, l_user_agent);

    return l_clob;

  end create_user_session;

  procedure generate_password_reset_token
  (
    p_json_parameters                 json_object_t
  )

  is

    l_email_address                   icam_users.email_address%type := db_twig.get_string_parameter(p_json_parameters, 'emailAddress');
    l_client_address                  icam_sessions.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');

  begin

    icam.generate_password_reset_token(l_email_address, l_client_address);

  end generate_password_reset_token;

  function generate_temporary_password
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_session_id                      icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);
    l_client_address                  icam_sessions.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');
    l_username                        icam_users.username%type := db_twig.get_string_parameter(p_json_parameters, 'username');
    l_clob                            clob;
    l_temporary_password              varchar2(10);

  begin

    l_temporary_password := icam.generate_temporary_password(l_session_id, l_client_address, l_username);

    select  json_object('temporaryPassword' is l_temporary_password)
      into  l_clob
      from  dual;

    return l_clob;

  end generate_temporary_password;

  function get_active_sessions
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return icam.get_active_sessions(icam.get_blocked_session_user_id(p_json_parameters));

  end get_active_sessions;

  function get_login_history
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return icam.get_login_history(icam.get_session_user_id_from_json(p_json_parameters));

  end get_login_history;

  function get_login_history_for_user
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return icam.get_login_history(icam.get_user_id(db_twig.get_string_parameter(p_json_parameters, 'username')));

  end get_login_history_for_user;

  function get_session_info
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return icam.get_session_info(icam.extract_session_id(p_json_parameters));

  end get_session_info;

  function get_user_list
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return icam.get_user_list;

  end get_user_list;

  function get_user_settings
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_username                        icam_users.username%type := db_twig.get_string_parameter(p_json_parameters, 'username');

  begin

    return icam.get_user_settings(l_username);

  end get_user_settings;

  procedure recover_username
  (
    p_json_parameters                 json_object_t
  )

  is

    l_email_address                   icam_users.email_address%type := db_twig.get_string_parameter(p_json_parameters, 'emailAddress');
    l_client_address                  confirmation_tokens.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');

  begin

    icam.recover_username(l_email_address, l_client_address);

  end recover_username;

  procedure reset_password
  (
    p_json_parameters                 json_object_t
  )

  is

    l_confirmation_token              confirmation_tokens.confirmation_token%type;
    l_client_address                  icam_sessions.client_address%type := db_twig.get_string_parameter(p_json_parameters, 'clientAddress');
    l_new_password                    varchar2(60);

  begin

    l_confirmation_token := db_twig.get_string_parameter(p_json_parameters, 'confirmationToken');
    l_new_password := db_twig.get_string_parameter(p_json_parameters, 'newPassword');

    icam.reset_password(l_confirmation_token, l_new_password, l_client_address);

  end reset_password;

  procedure terminate_user_session
  (
    p_json_parameters                 json_object_t
  )

  is

    l_session_id                      icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);

  begin

    icam.terminate_user_session(l_session_id);

  end terminate_user_session;

  procedure toggle_account_status
  (
    p_json_parameters                 json_object_t
  )

  is

    l_username                        icam_users.username%type;

  begin

    l_username := db_twig.get_string_parameter(p_json_parameters, 'username');
    icam.toggle_account_status(l_username);

  end toggle_account_status;

  procedure update_user_info
  (
    p_json_parameters                 json_object_t
  )

  is

    l_first_name                      icam_users.first_name%type;
    l_middle_name                     icam_users.middle_name%type;
    l_last_name                       icam_users.last_name%type;

  begin

    l_first_name := db_twig.get_string_parameter(p_json_parameters, 'firstName');
    l_last_name := db_twig.get_string_parameter(p_json_parameters, 'lastName');
    l_middle_name := db_twig.get_string_parameter(p_json_parameters, 'middleName', false);
    icam.update_user_info(icam.get_session_user_id_from_json(p_json_parameters),
      l_first_name, l_middle_name, l_last_name);

  end update_user_info;

  procedure update_user_preferences
  (
    p_json_parameters                 json_object_t
  )

  is

    l_default_timezone                icam_users.default_timezone%type := db_twig.get_string_parameter(p_json_parameters, 'defaultTimezone');
    l_auth_method                     icam_users.auth_method%type := db_twig.get_string_parameter(p_json_parameters, 'authMethod');

  begin

    icam.update_user_preferences(icam.get_session_user_id_from_json(p_json_parameters),
      l_auth_method, l_default_timezone);

  end update_user_preferences;

  procedure update_user_properties
  (
    p_json_parameters                 json_object_t
  )

  is

    l_username                        icam_users.username%type;
    l_session_limit                   icam_users.session_limit%type;
    l_session_inactivity_limit        icam_users.session_inactivity_limit%type;

  begin

    l_username := db_twig.get_string_parameter(p_json_parameters, 'username');
    l_session_limit := db_twig.get_number_parameter(p_json_parameters, 'sessionLimit');
    l_session_inactivity_limit := db_twig.get_number_parameter(p_json_parameters, 'sessionInactivityLimit');
    icam.update_user_properties(l_username, l_session_limit, l_session_inactivity_limit);

  end update_user_properties;

  procedure validate_change_email_code
  (
    p_json_parameters                 json_object_t
  )

  is

  begin

    icam.validate_change_email_code(icam.get_session_user_id_from_json(p_json_parameters),
      db_twig.get_string_parameter(p_json_parameters, 'confirmationCode'));

  end;

  function validate_login_authorization
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_confirmation_token              confirmation_tokens.confirmation_token%type :=
      db_twig.get_string_parameter(p_json_parameters, 'confirmationToken');

  begin

    return icam.validate_login_authorization(l_confirmation_token);

  end validate_login_authorization;

  procedure validate_new_email_address
  (
    p_json_parameters                 json_object_t
  )

  is

    l_email_address                   icam_users.email_address%type;

  begin

    l_email_address := db_twig.get_string_parameter(p_json_parameters, 'emailAddress');
    icam.validate_new_email_address(l_email_address);

  end validate_new_email_address;

  procedure validate_new_username
  (
    p_json_parameters                 json_object_t
  )

  is

    l_username                        icam_users.username%type;

  begin

    l_username := db_twig.get_string_parameter(p_json_parameters, 'username');
    icam.validate_new_username(l_username);

  end validate_new_username;

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  )

  is

  begin

    icam.validate_session(p_json_parameters, p_required_authorization_level, p_allow_blocked_session);

  end validate_session;

end restapi;
/
show errors package body restapi
