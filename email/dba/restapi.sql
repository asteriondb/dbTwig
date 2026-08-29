create or replace
package restapi

as

  procedure disable_smtp
  (
    p_json_parameters                 json_object_t
  );

/*

  function get_email_config

  API Entry Point: getEmailConfig

  The get_email_config function returns the outbound SMTP email configuration.

  This function can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    There are no required parameters.

  Embedded values in the returned JSON string value:

    smtpEmailSender           The outbound SMTP email sender's address.

    gmailClientId             The Gmail Client ID of the Google Gmail user that has authorized access to AsterionDB for outbound
                              SMTP email access.

    gmailClientSecret         The Gmail Client Secret of the Google Gmail user that has authorized access to AsterionDB for
                              outbound SMTP email access.

    debugSmtp                 This value is set to restapi.OPTION_ENABLED when debug information is being produced by the dbPluginServer.

*/

  function get_email_config
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function get_gmail_access_token_params

  API Entry Point: getGmailAccessTokenParams

  The get_gmail_access_token_params function allows a middle-tier client to retrieve the parameters required to obtain a GMail
  access token.  The middle-tier client must implement the required handshake in order to obtain the GMail access token.  See the
  Google documentation on OAuth for further information:

    https://developers.google.com/identity/protocols/oauth2/web-server

  This function can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    There are no required parameters.

  Embedded values in the returned JSON string value:

    getAccessTokenUrl         The URL to POST the OAuth request to.

    getAccessTokenData        The data to include in the OAuth request.

*/

  function get_gmail_access_token_params
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function get_gmail_signin_url

  API Entry Point: getGmailSigninUrl

  The get_gmail_signin_url function allows a client application to determine the URL the user will be redirected to in order to
  complete the GMail OAuth signin process.  See the following link for further information:

    https://developers.google.com/identity/protocols/oauth2/web-server

  This function can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    origin                    The URL of the page that will be initiating the Gmail authorization process (e.g. window.location.origin)

  Embedded values in the returned JSON string value:

    gmailSigninUrl            The URL that the web-app will redirect the user to.

*/

  function get_gmail_signin_url
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  procedure save_oauth_reply

  API Entry Point: saveOauthReply

  The save_oauth_reply procedure allows a middle-tier component to save the response received from an OAuth authorization handshake.

  This procedure can only be called by a user session that has been created by a system administrator.

  The OAuth handshake can only be initiated by a system administrator. As part of the handshake, the OAuth server receives a
  redirect URI that will process the OAuth reply.

  Embedded parameter values:

    There are no required parameters.

  The OAuth reply contains its own embedded parameters within a JSON object. These parameters are processed by the save_oauth_reply
  procedure.

*/

  procedure save_oauth_reply
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure send_email

  API Entry Point: sendEmail

  The send_email procedure sends an email to a specified recipient.

  You must specify either emailBody or emailBodyObjectId. Note that it is an error to specify both emailBody
  and emailBodyObjectId.

  Embedded parameter values:

    recipientData             A JSON object with the following items within:

      toList                  A JSON Array of objects that specifies the recipients on the to-list for the email. At
                              least one recipient must be specified. The elements within each object are:

        recipientEmail        The recipient's email address.

        recipientName         The name of the recipient.

      ccList                  An optional  JSON Array of objects that specifies the recipients on the cc-list for the email.
                              The elements within each object are:

        recipientEmail        The recipient's email address.

        recipientName         The name of the recipient.

      bccList                 An optional JSON Array of objects that specifies the recipients on the bcc-list for the email. The
                              elements within each object are:

        recipientEmail        The recipient's email address.

        recipientName         The name of the recipient.

    subject                   The email subject line.

    emailBody                 The text of the email to be sent. The length of the emailBody is limited to 4000 characters.

    emailBodyObjectId         The object-id of the object in AsterionDB that will provide the content for the body of the
                              email message.

    emailFormat               This value indicates whether the email is to be sent as plain-text or as an HTML message. It is
                              your responsibility to provide valid content if sending an HTML email message.

                              Valid values are restapi.HTML_EMAIL and restapi.TEXT_EMAIL.

  Possible exceptions returned:

    error_logging.FEATURE_DISABLED
    error_logging.INVALID_PARAMETERS

*/

  procedure send_email
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure send_email_to_all_users

  API Entry Point: sendEmailToAllUsers

  The send_email_to_all_users procedure sends an email to all users of the AsterionDB system.

  This procedure can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    subject                   The email subject line.

    emailText                 The text of the email to be sent.

  Possible exceptions returned:

    error_logging.FEATURE_DISABLED
    error_logging.INVALID_PARAMETERS

*/

  procedure send_email_to_all_users
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure send_test_email

  API Entry Point: sendTestEmail

  The send_test_email procedure sends a test email to the system administrator.

  This procedure can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    subject                   The email subject line.

    emailText                 The text of the email to be sent.

  Possible exceptions returned:

    error_logging.FEATURE_DISABLED
    error_logging.INVALID_PARAMETERS

*/

  procedure send_test_email
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure update_email_config

  API Entry Point: updateEmailConfig

  The update_email_config procedure allows a system administrator to update the SMTP outbound email configuration information for
  an AsterionDB installation.

  This procedure can only be called by a user session that has been created by a system administrator.

  This procedure required infromation that is generated as part of the Google GMail Oauth process.  See the
  Google documentation on OAuth for further information:

    https://developers.google.com/identity/protocols/oauth2/web-server

  Embedded parameter values:

    smtpEmailSender           The email address used to send outbound emails.

    redirectUri               The redirect URI that will be called by Gmail upon validation.

    gmailClientId             The GMail client ID.

    gmailClientSecret         The Gmail client secret.

    debugSmtp                 Set this value to restapi.OPTION_ENABLED to have the dbPluginServer generate SMTP degugging information.

*/

  procedure update_email_config
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure validate_session

  API Entry Point: validateSession

  This procedure is used by DbTwig to check session validation for every API call.

  This procedure is not to be called by a client applications.

*/

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  );

end restapi;
.
/
show errors package restapi
