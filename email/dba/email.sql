create or replace
package email as

/*

  Developer's notes:

  GMail test account is administered by support@asteriondb.com

  In order to test this when running locally w/out SSL (i.e. a developer), you must setup GMail's
  authorized redirect URI to

    http://localhost/dbTwig/asterionDB/oauthReply

  Also, ensure that your website root address is set to 'localhost' when DbTwig is listening on port 3030
  but receiving traffic from nginx redirected from port 80.

*/

-- Email format

  SERVICE_NAME                        constant varchar2(5) := 'email';

  HTML_EMAIL                          constant varchar2(4) := 'html';
  TEXT_EMAIL                          constant varchar2(4) := 'text';

  procedure disable_smtp;

  function get_email_config return clob;

  function get_gmail_access_token_params
  (
    p_authorization_code              varchar2
  )
  return clob;

  function get_gmail_signin_url
  (
    p_session_id                      raw,
    p_origin                          varchar2,
    p_client_addr                     varchar2,
    p_server_addr                     varchar2
  )
  return clob;

  procedure save_oauth_reply
  (
    p_json_parameters                 json_object_t
  );

  procedure send_auth_code
  (
    p_user_id                         number,
    p_auth_code                       varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  );

  procedure send_change_email_code
  (
    p_user_id                         number,
    p_new_email_address               varchar2,
    p_change_email_code               varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  );

  procedure send_confirm_signup_email
  (
    p_user_id                         number,
    p_confirmation_token              raw,
    p_website_root_address            varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  );

  procedure send_email
  (
    p_recipient_data                  json_object_t,
    p_headers                         json_array_t,
    p_subject                         outbound_email_log.subject%type,
    p_email_body                      clob,
    p_email_format                    varchar2,
    p_service_name                    varchar2
  );

  procedure send_email_to_all_users
  (
    p_subject                         outbound_email_log.subject%type,
    p_email_body                      varchar2
  );

  procedure send_login_url
  (
    p_user_id                         number,
    p_confirmation_token              raw,
    p_website_root_address            varchar2,
    p_mfa_login_page                  varchar2,
    p_service_name                    varchar2,
    p_expiration_date                 timestamp
  );

  procedure send_recovered_username_email
  (
    p_recipient_name                  varchar2,
    p_recipient_email                 varchar2,
    p_username                        varchar2,
    p_service_name                    varchar2
  );

  procedure send_reset_password_email
  (
    p_recipient_name                  varchar2,
    p_recipient_email                 varchar2,
    p_confirmation_token              varchar2,
    p_website_root_address            varchar2,
    p_password_reset_page             varchar2,
    p_service_name                    varchar2,
    p_expires_in_minutes              number
  );

  procedure send_test_email
  (
    p_user_id                         number,
    p_subject                         outbound_email_log.subject%type,
    p_email_body                      varchar2
  );

  procedure update_email_config
  (
    p_smtp_email_sender               email_configuration.smtp_email_sender%type,
    p_redirect_uri                    varchar2,
    p_gmail_client_id                 varchar2,
    p_gmail_client_secret             varchar2,
    p_debug_smtp                      email_configuration.debug_smtp%type
  );

end email;
.
/
show errors package email
