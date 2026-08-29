create or replace
package body restapi as

  procedure disable_smtp
  (
    p_json_parameters                 json_object_t
  )

  is

  begin

    email.disable_smtp;

  end disable_smtp;

  function get_email_config
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return email.get_email_config;

  end get_email_config;

  function get_gmail_access_token_params
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_authorization_code              varchar2(256) := db_twig.get_string(p_json_parameters, 'authorizationCode');

  begin

    icam.validate_session_id(p_json_parameters => p_json_parameters, p_allow_blocked_session => 'N',
      p_check_header_info => 'N');
    icam.site_administrator_check(p_json_parameters);
    return email.get_gmail_access_token_params(l_authorization_code);

  end get_gmail_access_token_params;

  function get_gmail_signin_url
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_origin                          varchar2(256) := db_twig.get_string(p_json_parameters, 'origin');
    l_session_id                      icam_sessions.session_id%type := icam.extract_session_id(p_json_parameters);
    l_client_addr                     icam_sessions.client_address%type := db_twig.get_string(p_json_parameters, 'clientAddress');
    l_server_addr                     icam_sessions.client_address%type := db_twig.get_string(p_json_parameters, 'serverAddress');

  begin

    return email.get_gmail_signin_url(l_session_id, l_origin, l_client_addr, l_server_addr);

  end get_gmail_signin_url;

-- This procedure is registered in middle_tier_map as having 'none' for the authorization level. This allows the default session validation
-- procedure to succeed. We then do the check w/out requiring header validation as the DbTwig middle-tier listener, which originates this
-- request, will not have matching headers.

  procedure save_oauth_reply
  (
    p_json_parameters                 json_object_t
  )

  is

  begin

    icam.validate_session_id(p_json_parameters => p_json_parameters, p_allow_blocked_session => 'N',
      p_check_header_info => 'N');
    icam.site_administrator_check(p_json_parameters);
    email.save_oauth_reply(p_json_parameters);

  end save_oauth_reply;

  procedure send_email
  (
    p_json_parameters                 json_object_t
  )

  is

    l_recipient_data                  json_object_t := db_twig.get_object(p_json_parameters, 'recipientData');
    l_subject                         outbound_email_log.subject%type := db_twig.get_string(p_json_parameters, 'subject');
    l_email_body                      varchar2(4000) := db_twig.get_string(p_json_parameters, 'emailBody', null);
--    l_email_body_object_id            vault_objects.object_id%type := db_twig.get_string(p_json_parameters, 'emailBodyObjectId', null);
    l_email_format                    varchar2(4) := db_twig.get_string(p_json_parameters, 'emailFormat');

  begin

--    dgbunker_service.send_email(l_recipient_data, l_subject, l_email_format, l_email_body, l_email_body_object_id);
    null;

  end send_email;

  procedure send_email_to_all_users
  (
    p_json_parameters                 json_object_t
  )

  is

    l_subject                         outbound_email_log.subject%type;
    l_email_body                      varchar2(3584);

  begin

    l_subject := db_twig.get_string(p_json_parameters, 'subject');
    l_email_body := db_twig.get_string(p_json_parameters, 'emailBody');

    email.send_email_to_all_users(l_subject, l_email_body);

  end send_email_to_all_users;

  procedure send_test_email
  (
    p_json_parameters                 json_object_t
  )

  is

    l_subject                         outbound_email_log.subject%type;
    l_email_body                      varchar2(3584);

  begin

    l_subject := db_twig.get_string(p_json_parameters, 'subject');
    l_email_body := db_twig.get_string(p_json_parameters, 'emailBody');
    email.send_test_email(icam.get_session_user_id_from_json(p_json_parameters), l_subject, l_email_body);

  end send_test_email;

  procedure update_email_config
  (
    p_json_parameters                 json_object_t
  )

  is

    l_smtp_email_sender               email_configuration.smtp_email_sender%type := db_twig.get_string(p_json_parameters, 'smtpEmailSender');
    l_gmail_client_id                 varchar2(72) := db_twig.get_string(p_json_parameters, 'gmailClientId');
    l_gmail_client_secret             varchar2(64) := db_twig.get_string(p_json_parameters, 'gmailClientSecret');
    l_redirect_uri                    varchar2(512) := db_twig.get_string(p_json_parameters, 'redirectUri');
    l_debug_smtp                      email_configuration.debug_smtp%type := db_twig.get_string(p_json_parameters, 'debugSmtp');

  begin

    email.update_email_config(l_smtp_email_sender, l_redirect_uri, l_gmail_client_id, l_gmail_client_secret, l_debug_smtp);

  end update_email_config;

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
