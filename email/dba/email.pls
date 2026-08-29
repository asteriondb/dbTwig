create or replace
package body email as

/*

Copyright 2014 - 2021 by AsterionDB Inc.  All rights reserved.

*/

  smtp_invalid_operation              exception;  -- Operation is invalid
  smtp_transient_error                exception;  -- Transient server error in 400 range
  smtp_permanent_error                exception;  -- Permanent server error in 500 range
  smtp_unsupported_scheme             exception;  -- Unsupported authentication scheme
  smtp_no_supported_scheme            exception;  -- No supported authentication scheme

  smtp_invalid_operation_errcode      constant pls_integer:= -29277;
  smtp_transient_error_errcode        constant pls_integer:= -20801;
  smtp_permanent_error_errcode        constant pls_integer:= -29279;
  smtp_unsupported_scheme_errcode     constant pls_integer:= -24249;
  smtp_no_supported_scheme_errcode    constant pls_integer:= -24250;

  pragma exception_init(smtp_invalid_operation,   -29277);
  pragma exception_init(smtp_transient_error,     -20801);
  pragma exception_init(smtp_permanent_error,     -29279);
  pragma exception_init(smtp_unsupported_scheme,  -24249);
  pragma exception_init(smtp_no_supported_scheme, -24250);

  s_fudge_factor                      constant pls_integer := 2;
  s_gmail_signin_url                  constant varchar2(128) := 'https://accounts.google.com/o/oauth2/v2/auth';
  s_gmail_token_url                   constant varchar2(64) := 'https://oauth2.googleapis.com/token';
  s_gmail_scope                       constant varchar2(256) := utl_url.escape('https://mail.google.com/', TRUE);
  s_smtp_server                       constant varchar2(128) := 'smtp.gmail.com';
  s_smtp_port                         constant pls_integer := 465;
  s_oauth_reply_page                  constant varchar2(29) := '/dbTwig/asterionDB/oauthReply';

  s_redirect_uri                      varchar2(512);

  s_smtp_enabled                      email_configuration.smtp_enabled%type := 'N';
  s_protocol                          varchar2(5) := 'https';
  s_gmail_client_id                   varchar2(72);
  s_gmail_client_secret               varchar2(64);
  s_token_valid_until                 timestamp with time zone;
  s_gmail_refresh_token               varchar2(256);
  s_gmail_access_token                varchar2(256);
  s_smtp_email_sender                 email_configuration.smtp_email_sender%type;
  s_debug_smtp                        varchar2(1) := 'N';

  PLUGIN_MODULE                       constant plugin_modules.plugin_module%type := 'smtpClient';
  s_plugin_process                    json_object_t;

  procedure quit

  is

    l_json_parameters                 json_object_t := json_object_t;
    l_json_result                     json_object_t;

  begin

    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'quit');

    dbplugin_api.disconnect_from_plugin_server(s_plugin_process);

  end quit;

  procedure write_body
  (
    p_mail_data                       varchar2
  )

  is

    l_json_parameters                 json_object_t := json_object_t;
    l_json_result                     json_object_t;

  begin

    if p_mail_data is null or p_mail_data = '' then

      raise_application_error(-20001, 'No data specified..');

    end if;

    l_json_parameters.put('body', p_mail_data);
    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'writeBody', l_json_parameters);

  end write_body;


  procedure write_body_from_file
  (
    p_filename                        varchar2
  )

  is

    l_json_result                     json_object_t;
    l_json_parameters                 json_object_t := json_object_t;

  begin

    if p_filename is null or p_filename = '' then

      raise_application_error(-20001, 'Content file not specified..');

    end if;

    l_json_parameters.put('filename', p_filename);
    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'writeBodyFromFile', l_json_parameters);

  end write_body_from_file;

---
--- Top shifted Email support routines
---

  procedure get_gmail_config

  is

    l_smtp_configuration              email_configuration.smtp_configuration%type;
    l_json_object                     json_object_t;
    l_valid_until                     varchar2(19);

  begin

    select  smtp_configuration, smtp_email_sender, smtp_enabled, debug_smtp
      into  l_smtp_configuration, s_smtp_email_sender, s_smtp_enabled, s_debug_smtp
      from  email_configuration;

    l_json_object := db_twig.get_dbtwig_profile;

    if 'Y' != l_json_object.get_string('sslEnabled') then

      s_protocol := 'http';

    else

      s_protocol := 'https';

    end if;

    l_json_object := json_object_t(l_smtp_configuration);

    l_valid_until := l_json_object.get_string('validUntil');

    select  to_utc_timestamp_tz(l_valid_until)
      into  s_token_valid_until
      from  dual;

    s_gmail_client_id := nvl(l_json_object.get_string('gmailClientId'), '');
    s_gmail_client_secret := nvl(l_json_object.get_string('gmailClientSecret'), '');
    s_gmail_refresh_token := nvl(l_json_object.get_string('refreshToken'), '');
    s_gmail_access_token := nvl(l_json_object.get_string('accessToken'), '');
    s_redirect_uri := nvl(l_json_object.get_string('redirectUri'), '');

  end get_gmail_config;

  procedure refresh_access_token
  (
    p_service_name                    varchar2
  )

  is

    l_token_info                      json_object_t;
    l_json_response                   json_object_t;
    l_json_parameters                 json_object_t := json_object_t;

  begin

    if systimestamp at time zone 'utc' < s_token_valid_until then

      return;

    end if;

    s_plugin_process := dbplugin_api.connect_to_plugin_server(dbplugin_api.CURL_PLUGIN_MODULE, p_service_name);

    l_json_parameters.put('url', s_gmail_token_url);
    l_json_parameters.put('postFields', 'client_id='||s_gmail_client_id||'&client_secret='||s_gmail_client_secret||'&grant_type=refresh_token&refresh_token='||s_gmail_refresh_token);

    l_json_response := dbplugin_api.call_plugin(s_plugin_process, 'post', l_json_parameters);

    dbplugin_api.disconnect_from_plugin_server(s_plugin_process);                 -- Disconnect from the plugin.

    l_token_info := l_json_response.get_object('data');

    if l_token_info.has('error') then

      raise_application_error(db_twig.INVALID_PARAMETERS, db_twig.INVALID_PARAMETERS_EMSG||' '|| l_token_info.get_string('error_description'));

    end if;

    save_oauth_reply(l_token_info);

  end refresh_access_token;

  procedure send_header
  (
    p_header                          clob
  )
  as

    l_json_result                     json_object_t;
    l_json_parameters                 json_object_t := json_object_t;

  begin

    if p_header is null then

      raise_application_error(db_twig.INVALID_PARAMETERS, db_twig.INVALID_PARAMETERS_EMSG);

    end if;

    l_json_parameters.put('header', p_header);
    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'writeHeader', l_json_parameters);

  end send_header;

  procedure send_email_action
  (
    p_recipient_data                  json_object_t,
    p_headers                         json_array_t,
    p_subject                         varchar2,
    p_email_body                      clob,
    p_email_format                    varchar2,
    p_service_name                    varchar2,
    p_sender_email                    varchar2 default null
  )
  is

    l_sender_email                    email_configuration.smtp_email_sender%type := p_sender_email;
    l_json_object                     json_object_t := json_object_t;
    l_to_header                       clob := null;
    l_cc_header                       clob := null;
    l_clob                            clob;
    l_content_file                    varchar2(256);
    l_json_parameters                 json_object_t := json_object_t;
    l_json_result                     json_object_t;

    l_to_list                         json_array_t;
    l_cc_list                         json_array_t;
    l_bcc_list                        json_array_t;

  begin

/*    if (p_email_body is not null and p_email_body_object_id is not null) or
       (p_email_body is null and p_email_body_object_id is null) then

      raise_application_error(db_twig.INVALID_PARAMETERS, db_twig.INVALID_PARAMETERS_EMSG);

    end if; */

    if 'N' = s_smtp_enabled then

      raise_application_error(db_twig.FEATURE_DISABLED, db_twig.FEATURE_DISABLED_EMSG);

    end if;

    l_to_list := p_recipient_data.get_array('toList');
    if 0 = l_to_list.get_size then

      raise_application_error(db_twig.INVALID_PARAMETERS, db_twig.INVALID_PARAMETERS_EMSG||' '||'At least one recipient must be specified.');

    end if;

    if l_sender_email is null then

      l_sender_email := s_smtp_email_sender;

    end if;

    refresh_access_token(p_service_name);

    s_plugin_process := dbplugin_api.connect_to_plugin_server(PLUGIN_MODULE, p_service_name);                    -- Connect to the dbplugin_api.

    l_json_parameters.put('smtpServer', s_smtp_server);
    l_json_parameters.put('port', to_char(s_smtp_port));
    l_json_parameters.put('secureSmtp', 'Y');
    l_json_parameters.put('debug', s_debug_smtp);
    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'openConnection', l_json_parameters);

    l_json_parameters := json_object_t;
    l_json_parameters.put('smtpServer', s_smtp_server);
    l_json_parameters.put('accessToken', s_gmail_access_token);

    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'gmailAuthorize', l_json_parameters);
    l_json_parameters.remove('accessToken');

    l_json_parameters.put('sender', l_sender_email);
    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'mail', l_json_parameters);
    l_json_parameters.remove('sender');

    l_cc_list := p_recipient_data.get_array('ccList');
    l_bcc_list := p_recipient_data.get_array('bccList');

    for x in 0 .. l_to_list.get_size - 1 loop

      l_json_object := treat(l_to_list.get(x) as json_object_t);

      l_json_parameters.put('recipient', l_json_object.get_string('email'));
      l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'rcpt', l_json_parameters);

      if l_to_header is null then

        l_to_header := 'To: ';

      else

        l_to_header := l_to_header||', ';

      end if;

      l_to_header := l_to_header||l_json_object.get_string('name')||' <'||l_json_object.get_string('email')||'>';

    end loop;

    if l_cc_list is not null then

      for x in 0 .. l_cc_list.get_size - 1 loop

        l_json_object := treat(l_cc_list.get(x) as json_object_t);

        l_json_parameters.put('recipient', l_json_object.get_string('email'));
        l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'rcpt', l_json_parameters);

        if l_cc_header is null then

          l_cc_header := 'Cc: ';

        else

          l_cc_header := l_cc_header||', ';

        end if;

        l_cc_header := l_cc_header||l_json_object.get_string('name')||' <'||l_json_object.get_string('email')||'>';

      end loop;

    end if;

    if l_bcc_list is not null then

      for x in 0 .. l_bcc_list.get_size - 1 loop

        l_json_object := treat(l_bcc_list.get(x) as json_object_t);

        l_json_parameters.put('recipient', l_json_object.get_string('email'));
        l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'rcpt', l_json_parameters);

      end loop;

    end if;

    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'openData');

    if p_headers is not null then

      for x in 0 .. p_headers.get_size - 1 loop

        send_header(p_headers.get_string(x));

      end loop;

    end if;

    send_header('From: AsterionDB <'||l_sender_email||'>');
    send_header(l_to_header);
    if l_cc_header is not null then

      send_header(l_cc_header);

    end if;
    send_header('Subject: '||p_subject);
    send_header('AsterionDB-Sender: AsterionDB Digital Bunker');

    if email.TEXT_EMAIL = p_email_format then

      send_header('Content-Type: text/plain; charset=UTF-8');
      send_header('Content-Transfer-Encoding: 7bit');

    else

      send_header('Content-Type: text/html; charset=UTF-8');
      send_header('Content-Transfer-Encoding: 7bit');

    end if;

/*    if p_email_body_object_id is not null then

      l_content_file := digital_bunker.generate_object_filename(p_object_id => p_email_body_object_id, p_access_mode => email.READ_ACCESS,
        p_gateway_name => s_plugin_process.get_string('pluginServer'));
      write_body_from_file(l_content_file);

    else

      write_body(p_email_body);

    end if; */

    write_body(p_email_body);

    l_json_result := dbplugin_api.call_plugin(s_plugin_process, 'closeData');
    quit();

    l_clob := p_recipient_data.to_clob;

    insert into outbound_email_log
      (email_id, subject, sender_email, recipient_data)
    values
      (id_seq.nextval, p_subject, l_sender_email, l_clob);

  exception

  when smtp_transient_error or smtp_permanent_error then

    begin

      quit();

    exception

      when smtp_transient_error or smtp_permanent_error then

        null; -- When the SMTP server is down or unavailable, we don't have
              -- a connection to the server. The QUIT call raises an
              -- exception that we can ignore.
    end;

    raise_application_error(-20000, 'Failed to send mail due to the following error: ' || sqlerrm);

  end send_email_action;

---
--- Exposed email routines
---

  procedure disable_smtp

  is

  begin

    update  email_configuration
       set  smtp_enabled = 'N';

  end disable_smtp;

  function get_email_config return clob as

    l_clob                            clob;
    l_json_object                     json_object_t := json_object_t;

  begin

    get_gmail_config;

    l_json_object.put('smtpEnabled', s_smtp_enabled);
    l_json_object.put('smtpEmailSender', s_smtp_email_sender);
    l_json_object.put('gmailClientId', s_gmail_client_id);
    l_json_object.put('gmailClientSecret', s_gmail_client_secret);
    l_json_object.put('redirectUri', s_redirect_uri);
    l_json_object.put('debugSmtp', s_debug_smtp);

    return l_json_object.to_clob;

  end get_email_config;

  function get_gmail_access_token_params
  (
    p_authorization_code              varchar2
  )
  return clob

  is

    l_clob                            clob;
    l_true                            boolean := TRUE;
    l_json_object                     json_object_t := json_object_t;

  begin

    get_gmail_config;

    l_clob := 'client_id='||s_gmail_client_id||'&client_secret='||s_gmail_client_secret||'&redirect_uri='||utl_url.escape(s_redirect_uri, l_true)||
                          '&grant_type=authorization_code&code='||p_authorization_code;

    l_json_object.put('getAccessTokenData', l_clob);
    l_json_object.put('getAccessTokenUrl', s_gmail_token_url);

    return l_json_object.to_clob;

  end get_gmail_access_token_params;

  function get_gmail_signin_url
  (
    p_session_id                      raw,
    p_origin                          varchar2,
    p_client_addr                     varchar2,
    p_server_addr                     varchar2
  )
  return clob

  is

    l_signin_url                      clob;
    l_origin                          varchar2(256) := utl_url.escape(p_origin||'/'||rawtohex(p_session_id), TRUE);
    l_json_object                     json_object_t := json_object_t;

/*    l_html_object_type                object_types.object_type_id%type;
    l_txt_object_type                 object_types.object_type_id%type; */

  begin

/*    if not objects.file_extension_is_enabled('txt') or not objects.file_extension_is_enabled('html') then

      raise_application_error(dgbunker_service.GENERIC_ERROR, 'Support for HTML and TXT files must be enabled.');

    end if; */

    get_gmail_config;

    l_signin_url := s_gmail_signin_url||'?scope='||s_gmail_scope||'&access_type=offline'||
      '&include_granted_scopes=true&response_type=code&'||'redirect_uri='||
      utl_url.escape(s_redirect_uri, TRUE)||'&client_id='||s_gmail_client_id||
      '&login_hint='||s_smtp_email_sender||'&prompt=consent&state='||l_origin;

    l_json_object.put('gmailSigninUrl', l_signin_url);
    return l_json_object.to_clob;

  end get_gmail_signin_url;

  procedure save_oauth_reply
  (
    p_json_parameters                 json_object_t
  )

  is

    l_smtp_configuration              email_configuration.smtp_configuration%type;
    l_json_object                     json_object_t;
    l_smtp_enabled                    email_configuration.smtp_enabled%type := 'Y';

  begin

    select  smtp_configuration
      into  l_smtp_configuration
      from  email_configuration;

    l_json_object := json_object_t(l_smtp_configuration);

    if p_json_parameters.get_string('error') is not null then

      l_smtp_enabled := 'N';

      l_json_object.put('error', p_json_parameters.get_string('error'));
      l_json_object.put('errorDescription', p_json_parameters.get_string('error_description'));

      l_json_object.remove('accessToken');
      l_json_object.remove('refreshToken');
      l_json_object.remove('validUntil');
      l_json_object.remove('scope');
      l_json_object.remove('tokenType');

    else

      l_json_object.remove('error');
      s_gmail_access_token := p_json_parameters.get_string('access_token');
      l_json_object.put('accessToken', s_gmail_access_token);

      if p_json_parameters.get_string('refresh_token') is not null then

        l_json_object.put('refreshToken', p_json_parameters.get_string('refresh_token'));

      end if;

      l_json_object.put('validUntil', to_char(systimestamp at time zone 'utc' + (p_json_parameters.get_number('expires_in') - s_fudge_factor) /
        db_twig.SECONDS_PER_DAY, 'YYYY-MM-DD"T"hh24:mm:ss'));
      l_json_object.put('scope', p_json_parameters.get_string('scope'));
      l_json_object.put('tokenType', p_json_parameters.get_string('token_type'));

    end if;

    l_smtp_configuration := l_json_object.to_string();

    update  email_configuration
       set  smtp_enabled = l_smtp_enabled,
            smtp_configuration = l_smtp_configuration;

--    commit;

  end save_oauth_reply;

  procedure send_auth_code
  (
    p_user_id                         number,
    p_auth_code                       varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  )

  is

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;
    l_default_timezone                icam_users.default_timezone%type;
    l_email_address                   icam_users.email_address%type;
    l_recipient_name                  varchar2(61);
    l_offset                          pls_integer;

  begin

    get_gmail_config;

    select  first_name||' '||last_name, email_address, default_timezone
      into  l_recipient_name, l_email_address, l_default_timezone
      from  icam_users
     where  user_id = p_user_id;

    l_offset := to_number(substr(tz_offset(l_default_timezone), 1, 1)||
      (substr(tz_offset(l_default_timezone), 2, 2) * 60) + (substr(tz_offset(l_default_timezone), 5, 2)));

    l_to.put('email', l_email_address);
    l_to.put('name', l_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, 'AsterionDB Login Authorization Code',
      'Hello '|| l_recipient_name || ':' || utl_tcp.crlf || utl_tcp.crlf ||
      'Your login authorization code is: ' || p_auth_code || utl_tcp.crlf || utl_tcp.crlf ||
      'Please note that this authorization code will expire at ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'hh:mi am ') ||
      l_default_timezone||' on ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'mm/dd/yyyy'), p_service_name, email.TEXT_EMAIL);

  end send_auth_code;

  procedure send_change_email_code
  (
    p_user_id                         number,
    p_new_email_address               varchar2,
    p_change_email_code               varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  )

  is

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;
    l_default_timezone                icam_users.default_timezone%type;
    l_old_email_address               icam_users.email_address%type;
    l_recipient_name                  varchar2(61);
    l_offset                          pls_integer;

  begin

    get_gmail_config;

    select  first_name||' '||last_name, email_address, default_timezone
      into  l_recipient_name, l_old_email_address, l_default_timezone
      from  icam_users
     where  user_id = p_user_id;

    l_offset := to_number(substr(tz_offset(l_default_timezone), 1, 1)||
      (substr(tz_offset(l_default_timezone), 2, 2) * 60) + (substr(tz_offset(l_default_timezone), 5, 2)));

    l_to.put('email', p_new_email_address);
    l_to.put('name', l_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, 'Confirm your email address registered with AsterionDB',
      'Hello '|| l_recipient_name || ':' || utl_tcp.crlf || utl_tcp.crlf ||
      'Please validate your new email address by entering the following code: ' || p_change_email_code || utl_tcp.crlf || utl_tcp.crlf ||
      'Please note that your confirmation code will expire at ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'hh:mi am ') ||
      l_default_timezone||' on ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'mm/dd/yyyy'), p_service_name, email.TEXT_EMAIL);

  end send_change_email_code;

  procedure send_confirm_signup_email
  (
    p_user_id                         number,
    p_confirmation_token              raw,
    p_website_root_address            varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  )
  as

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;
    l_default_timezone                icam_users.default_timezone%type;
    l_email_address                   icam_users.email_address%type;
    l_recipient_name                  varchar2(61);
    l_offset                          pls_integer;

  begin

    get_gmail_config;

    select  first_name||' '||last_name, email_address, default_timezone
      into  l_recipient_name, l_email_address, l_default_timezone
      from  icam_users
     where  user_id = p_user_id;

    l_offset := to_number(substr(tz_offset(l_default_timezone), 1, 1)||
      (substr(tz_offset(l_default_timezone), 2, 2) * 60) + (substr(tz_offset(l_default_timezone), 5, 2)));

    l_to.put('email', l_email_address);
    l_to.put('name', l_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, 'Confirm your AsterionDB Database Vault account',
      'Hello '|| l_recipient_name || ':' || utl_tcp.crlf || utl_tcp.crlf ||
      'Please validate your new account by accessing the following link:' || utl_tcp.crlf || utl_tcp.crlf ||
      s_protocol||'://'||p_website_root_address||'/confirmSignup?'||p_confirmation_token || utl_tcp.crlf || utl_tcp.crlf ||
      'Please note that your confirmation token will expire at ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'hh:mi am ') ||
      l_default_timezone||' on ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'mm/dd/yyyy'), p_service_name, email.TEXT_EMAIL);

  end send_confirm_signup_email;

  procedure send_email
  (
    p_recipient_data                  json_object_t,
    p_headers                         json_array_t,
    p_subject                         outbound_email_log.subject%type,
    p_email_body                      clob,
    p_email_format                    varchar2,
    p_service_name                    varchar2
  )

  is

  begin

    get_gmail_config;

    send_email_action(p_recipient_data, p_headers, p_subject, p_email_body, p_service_name, p_email_format);

  end send_email;

  procedure send_email_to_all_users
  (
    p_subject                         outbound_email_log.subject%type,
    p_email_body                      varchar2
  )

  is

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;

  begin

    get_gmail_config;

/*    for user_row in
    ( select  first_name ||' '||middle_name||' '||last_name name, email_address
        from  icam_users
       where  account_type = 'user'
         and  account_status = dgbunker_service.AS_ACTIVE
    )
    loop

      l_to.put('email', user_row.email_address);
      l_to.put('name', user_row.name);
      l_to_list.append(l_to);
      l_recipient_data.put('toList', l_to_list);

    end loop;

    send_email_action(l_recipient_data, null, p_subject,
      'Hello ' || utl_tcp.crlf || utl_tcp.crlf || p_email_body, null, email.TEXT_EMAIL); */

  end send_email_to_all_users;

/*
  procedure send_invitation
  (
    p_invitation_token                invited_users.invitation_token%type
  )

  is

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;
    l_default_timezone                icam_users.default_timezone%type;
    l_expiration_date                 confirmation_tokens.expiration_date%type;
    l_creation_date                   confirmation_tokens.creation_date%type;
    l_recipient_name                  varchar2(61);
    l_invited_by                      varchar2(61);
    l_email_address                   icam_users.email_address%type;
    l_offset                          pls_integer;
    l_invitation_note                 invited_users.invitation_note%type;

  begin

    get_gmail_config;

    select  i.first_name||' '||i.last_name, i.email_address, default_timezone,
            o.first_name||' '||o.last_name, creation_date, expiration_date, invitation_note
      into  l_recipient_name, l_email_address, l_default_timezone, l_invited_by,
            l_creation_date, l_expiration_date, l_invitation_note
      from  icam_users o, invited_users i
     where  user_id = user_sending_invitation
       and  invitation_token = p_invitation_token;

    l_offset := to_number(substr(tz_offset(l_default_timezone), 1, 1)||
      (substr(tz_offset(l_default_timezone), 2, 2) * 60) + (substr(tz_offset(l_default_timezone), 5, 2)));

    l_to.put('email', l_email_address);
    l_to.put('name', l_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, 'SecureObject Vault Invitation',
      'Hello '|| l_recipient_name || ':' || utl_tcp.crlf || utl_tcp.crlf ||
      'You have been invited by ' || l_invited_by || ' to register an account at the SecureObject Vault.  '||
      utl_tcp.crlf || utl_tcp.crlf || l_invitation_note || utl_tcp.crlf || utl_tcp.crlf ||
      'You can create an account by clicking on the following link:' || utl_tcp.crlf || utl_tcp.crlf ||
      s_protocol||'://'||s_website_root_address||'/acceptInvitation?'||p_invitation_token || utl_tcp.crlf || utl_tcp.crlf ||
      'Please note that your invitation will expire at ' ||
      to_char(l_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'hh:mi am ') ||
      l_default_timezone||' on ' ||
      to_char(l_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'mm/dd/yyyy') ||
      utl_tcp.crlf || utl_tcp.crlf || 'Here''s a copy of our User''s Guide.  The introduction starts in chapter 5. ' ||
      utl_tcp.crlf || utl_tcp.crlf ||'https://cloud-eval.asteriondb.com/objectVault/usersGuide', null, email.TEXT_EMAIL);

  end send_invitation;
*/

  procedure send_login_url
  (
    p_user_id                         number,
    p_confirmation_token              raw,
    p_website_root_address            varchar2,
    p_mfa_login_page                  varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  )

  is

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;
    l_default_timezone                icam_users.default_timezone%type;
    l_email_address                   icam_users.email_address%type;
    l_recipient_name                  varchar2(61);
    l_offset                          pls_integer;

  begin

    get_gmail_config;

    select  first_name||' '||last_name, email_address, default_timezone
      into  l_recipient_name, l_email_address, l_default_timezone
      from  icam_users
     where  user_id = p_user_id;

    l_offset := to_number(substr(tz_offset(l_default_timezone), 1, 1)||
      (substr(tz_offset(l_default_timezone), 2, 2) * 60) + (substr(tz_offset(l_default_timezone), 5, 2)));

    l_to.put('email', l_email_address);
    l_to.put('name', l_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, 'AsterionDB Secure Login URL',
      'Hello '|| l_recipient_name || ':' || utl_tcp.crlf || utl_tcp.crlf ||
      'This unique URL will allow you to login to AsterionDB: '|| utl_tcp.crlf || utl_tcp.crlf ||
      s_protocol||'://'||p_website_root_address||'/'||p_mfa_login_page||'?'||p_confirmation_token || utl_tcp.crlf || utl_tcp.crlf ||
      'Please note that this URL will expire at ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'hh:mi am ') ||
      l_default_timezone||' on ' ||
      to_char(p_expiration_date + ((l_offset * 60) / db_twig.SECONDS_PER_DAY), 'mm/dd/yyyy'), p_service_name, email.TEXT_EMAIL);

  end send_login_url;

  procedure send_recovered_username_email
  (
    p_recipient_name                  varchar2,
    p_recipient_email                 varchar2,
    p_username                        varchar2,
    p_service_name                    varchar2
  )

  as

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;

  begin

    get_gmail_config;

    l_to.put('email', p_recipient_email);
    l_to.put('name', p_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, 'AsterionDB Username Recovery',
      'Hello '|| p_recipient_name || ':' || utl_tcp.crlf || utl_tcp.crlf ||
      'Your AsterionDB Username is: ' || p_username, p_service_name, email.TEXT_EMAIL);

  end send_recovered_username_email;

  procedure send_reset_password_email
  (
    p_recipient_name                  varchar2,
    p_recipient_email                 varchar2,
    p_confirmation_token              varchar2,
    p_website_root_address            varchar2,
    p_password_reset_page             varchar2,
    p_service_name                    varchar2,
    p_expires_in_minutes              number
  )

  as

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;

  begin

    get_gmail_config;

    l_to.put('email', p_recipient_email);
    l_to.put('name', p_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, 'Reset your AsterionDB Database Vault password',
      'Hello '|| p_recipient_name || ':' || utl_tcp.crlf || utl_tcp.crlf ||
      'To reset the password for your AsterionDB account, access the following link:' || utl_tcp.crlf || utl_tcp.crlf ||
      s_protocol||'://'||p_website_root_address||p_password_reset_page||'?'||p_confirmation_token|| utl_tcp.crlf || utl_tcp.crlf||
      'Note: this link will expire in '||p_expires_in_minutes||' minutes.', p_service_name, email.TEXT_EMAIL);

  end send_reset_password_email;

  procedure send_test_email
  (
    p_user_id                         number,
    p_subject                         outbound_email_log.subject%type,
    p_email_body                      varchar2
  )

  is

    l_recipient_data                  json_object_t := json_object_t;
    l_to_list                         json_array_t := json_array_t;
    l_to                              json_object_t := json_object_t;

    l_recipient_name                  varchar2(128);

  begin

    get_gmail_config;

    select  first_name ||' '||middle_name||' '||last_name
      into  l_recipient_name
      from  icam_users
     where  user_id = p_user_id;

    l_to.put('email', s_smtp_email_sender);
    l_to.put('name', l_recipient_name);
    l_to_list.append(l_to);
    l_recipient_data.put('toList', l_to_list);

    send_email_action(l_recipient_data, null, p_subject, 'Hello ' || l_recipient_name || -- temporary workaround...
      utl_tcp.crlf || utl_tcp.crlf || p_email_body, SERVICE_NAME, email.TEXT_EMAIL);

  end send_test_email;

  procedure update_email_config
  (
    p_smtp_email_sender               email_configuration.smtp_email_sender%type,
    p_redirect_uri                    varchar2,
    p_gmail_client_id                 varchar2,
    p_gmail_client_secret             varchar2,
    p_debug_smtp                      email_configuration.debug_smtp%type
  )

  is

    l_smtp_configuration              email_configuration.smtp_configuration%type;
    l_json_object                     json_object_t;

  begin

    select  smtp_configuration
      into  l_smtp_configuration
      from  email_configuration;

    l_json_object := json_object_t(l_smtp_configuration);
    l_json_object.put('gmailClientId', p_gmail_client_id);
    l_json_object.put('gmailClientSecret', p_gmail_client_secret);
    l_json_object.put('redirectUri', p_redirect_uri);

    l_smtp_configuration := l_json_object.to_string;

    s_smtp_enabled := 'N';

    update  email_configuration
       set  smtp_enabled = 'N',
            smtp_email_sender = p_smtp_email_sender,
            smtp_configuration = l_smtp_configuration,
            debug_smtp = p_debug_smtp;

  end update_email_config;

end email;
/
show errors package body email
