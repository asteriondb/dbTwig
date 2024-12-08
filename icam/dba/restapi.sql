create or replace
package restapi as

/*

  function abandon_for_current_session

  API Entry Point: abandonForCurrentSession

  The abandon_session_for_another procedure allows a user application to abandon an active session for the current session which is
  blocked due to a session limit exception.

  This procedure can only be called by a session that is currently blocked due to a session limit exception.

  The user application will have to call restapi.get_active_sessions in order to present a list to the user of sessions
  that can be terminated.

  Embedded parameter values:

    sessionToTerminate        The session_id of the session to terminate in favor of the current session.

  Embedded values in the returned JSON string value:

    sessionStatus             Returned value, Active or Blocked, indicates the session status.

  Possible exceptions thrown:

    error_logging.UNABLE_TO_TERMINATE
    error_logging.UNBLOCK_SESSION_FAILED

*/

  function abandon_for_current_session
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*
  function activate_blocked_session

  API Entry Point: activateBlockedSession

  The activate_blocked_session function is called by a blocked session that is requesting activation after the user has terminated
  an active session (i.e. on another browser/computer).

  Embedded parameter values:

    There are no required parameters. The activate_blocked_session function determines the blocked session-id from the embedded
    parameters that are required by the DbTwig middle-tier handler.

  Embedded values in the returned JSON string value:

    sessionStatus             Returned value, Active or Blocked, indicates the session status.
*/

  function activate_blocked_session
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*
  function change_password

  API Entry Point: changePassword

  The change_password function allows a user to change their password.  The calling application can also indicate that the user
  has accepted the terms of use.

  Embedded parameter values:

    currentPassword           The user's current password
    newPassword               The user's new password
    termsAccepted             An optional value indicating that the user has accepted the terms of use.  Valid values are 'Y'
                              or 'N'.

  Embedded values in the returned JSON string value:

    sessionStatus             The resulting session status - 'Active' or 'Blocked'

  Possible exceptions returned:

    error_logging.CHANGE_PASSWORD_FAILED
    error_logging.NEW_OLD_PASSWORDS_MATCH

*/

  function change_password
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  procedure check_confirmation_token

  API Entry Point: checkConfirmationToken

  The check_confirmation_token procedure allows a client application to validate a system generated confirmation token.
  Confirmation tokens are generated as a step in various AsterionDB authorization workflows.  The workflows that generate a
  confirmation token are:

    User initiated password recovery.

  Embedded parameter values:

    confirmationToken         The system generated confirmation token which was received in an email that was sent by the AsterionDB
                              system.

  Possible exceptions returned:

    error_logging.INVALID_CONFIRMATION_DATA

*/

  procedure check_confirmation_token
  (
    p_json_parameters                 json_object_t
  );

/*

  function create_user_account

  API Entry Point: create_user_account

  The create_user_account function allows a system administrator to enroll a user into AsterionDB.  This function returns a temporary
  password that must be communicated to the user.  Upon initially logging in the new user will have to change their password.

  This function can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    username                  The new user's username.

    firstName                 The new user's first name.

    middleName                The new user's middle name.

    lastName                  The new user's last name.

    emailAddress              The new user's email address.

    defaultTimezone           The new user's default timezone (e.g. America/Los_Angeles).

  Embedded values in the returned JSON string value:

    temporaryPassword         The new user's temporary password.
    userId                    The new user's user-id.

  Possible exceptions returned:

    error_logging.PASSWORD_REQUIRED
    error_logging.NEW_USERS_NOT_ALLOWED
    error_logging.RESTRICTED_TO_DOMAIN
    error_logging.OWNER_ALREADY_EXISTS
    error_logging.USERNAME_TAKEN
    error_logging.EMAIL_ADDRESS_EXISTS

*/

  function create_user_account
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function create_user_session

  API Entry Point: createUserSession

  The create_user_session function creates a user session which is synonymous to logging in.  This function must be called before
  making any calls that require a sessionId.  This is for interactive applications only (e.g. web client, file upload client).
  This function is not to be called by integrated applications that utilize an Client API Token.

  Embedded parameter values:

    identification            The user's username or email address.

    password                  The user's password.

  Embedded values in the returned JSON object:

    sessionId                 The user's session_id value.

    sessionStatus             The user session's status.  Possible values are:

                                SS_ACTIVE - all API features available

                                SS_SESSION_LIMIT - logon successful but restricted due to session limit

                                SS_CHANGE_PASSWORD - logon successful but user is required to change their
                                password

                              For a session that is restricted due to a session limit, the client application should issue calls to
                              restapi.get_active_sessions to get a list of active sessions and then call
                              restapi.activate_blocked_session or restapi.terminate_session depending
                              upon the action to be taken.

                              For a session that is restricted due to a password reset requirement, the client application must
                              present a screen, collect the appropriate input values and call restapi.change_password.

    username                  The logged in user's name.

    firstName                 The user's first name.

    middleName                The user's middle name/initial.

    lastName                  The user's last name.

    emailAddress              The user's primary email address.

    accountType               The account type.  Valid values are:

                                AT_USER
                                AT_EVALUATOR
                                AT_OWNER

    defaultTimezone           The user's default timezone (e.g. America/Los_Angeles).

    authMethod                The users's authorization method. Valid values are:

                                AM_PASSWORD
                                AM_AUTH_CODE
                                AM_LOGIC_URL

    grantedPermissions        The grantedPermissions value is a JSON array containing the following key/value pairs:

                                permission        The permission granted to the user.
                                permissionClass   The class/group of permissions that the permission is a part of.

  Possible exceptions returned:

    error_logging.USER_OR_PASSWORD
    error_logging.ACCOUNT_LOCKED

*/

  function create_user_session
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  procedure generate_password_reset_token

  API Entry Point: generatePasswordResetToken

  The generate_password_reset_token procedure allows a client application to generate a unique weblink that will allow an
  unauthenticated user (i.e. not logged in) to recover their password.  This function requires outbound SMTP email support to
  be enabled.  The AsterionDB system will send an email to the user with a weblink that can be used to access a password reset
  page.

  This procedure is callable by unauthenticated users.  It supports password recovery when the user has forgotten their password.
  The application calling this procedure should communicate to the user that a password reset email will be sent to the specified email
  address.

  Note that if the email address is not registered in the system, a reset email will not be sent.  This procedure will not
  inform the caller if the email address is valid or not.

  The calling application should indicate to the user that an email will be sent to the specified address if it is valid.

  Embedded parameter values:

    emailAddress              The user's email address.

*/

  procedure generate_password_reset_token
  (
    p_json_parameters                 json_object_t
  );

/*

  function generate_temporary_password

  API Entry Point: generateTemporaryPassword

  The generate_temporary_password function allows a system administrator to reset and generate a temporary password for a user.

  This function can only be called by a user session that has been created by a system administrator.

  It is the client application's responsiblity to communicate the new, temporary password to the end user.

  Embedded parameter values:

    username                  The username of the user whose password will be reset and set to a temporary value.

  Embedded values in the returned JSON string value:

    temporaryPassword         The user's new, temporary password.

*/

  function generate_temporary_password
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function get_active_sessions

  API Entry Point: getActiveSessions

  The get_active_sessions function allows a blocked Web Application session to obtain information about other active sessions for
  the blocked user.  This information can be used by the end user to make a determination of how to activate a blocked session
  (i.e. terminate another session).

  Embedded parameter values:

    There are no required parameters.

  Embedded values in the returned JSON string value:

    The JSON object returned by this function contains an array of objects with information pertaining to active sessions that are
    blocking the calling session.  The embedded values in each array element contsins the following attributes:

      lastActivity              A UNIX timestamp value indicating the date and time of last activity for a session.

      sessionId                 The session_id value of a user's active session.

      clientAddress             The IP address of the client machine.

      sessionCreated            A UNIX timestamp value indicating the date and time that the active session was created.

      userAgent                 The active session's user-agent.

*/

  function get_active_sessions
  (
    p_json_parameters                 json_object_t
  )
  return clob;

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
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function get_login_history_for_user

  API Entry Point: getLoginHistoryForUser

  The get_login_history_for_user function allows a system administrator to retrieve a user's login history.

  This function can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    username                  The user whose login history will be retrieved.

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

  function get_login_history_for_user
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function get_session_info

  API Entry Point: getSessionInfo

  The get_session_info allows a client application to retrieve it's session information.

  Embedded parameter values:

    There are no required parameters.

  The JSON object returned by this function contains the following properties:

    sessionId               The session ID.

    sessionStatus           The present status of the session.  Possible values are:

                              SS_ACTIVE
                              SS_SESSION_LIMIT
                              SS_CHANGE_PASSWORD
                              SS_TERMINATED

    firstName               The user's first name.

    middleName              The user's middle name.

    lastName                The user's last name.

    emailAddress            The user's email address.

    accountType             The account type.  Valid values are:

                              AT_USER
                              AT_EVALUATOR
                              AT_OWNER

    authMethod              The users's authorization method. Valid values are:

                              AM_PASSWORD
                              AM_AUTH_CODE
                              AM_LOGIC_URL

    defaultTimezone         The user's default timezone (e.g. America/Los_Angeles).

*/

  function get_session_info
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function get_user_list

  API Entry Point: getUserList

  The get_user_list function allows a client application to retrieve a list of user's of the AsterionDB system.

  This function can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    There are no required parameters.

  The JSON object returned by this function contains an array of user entries with the following properties:

    username                  The username.

    emailAddress              The user's email address.

    firstName                 The user's first name.

    middleName                The user's middle name.

    lastName                  The user's last name.

    accountStatus             The user account status.  Possible values are:

                                AS_ACTIVE
                                AS_LOCKED
                                AS_UNCONFIRMED
                                AS_CHANGE_PASSWORD

    accountType               The account type.  Valid values are:

                                AT_USER
                                AT_EVALUATOR
                                AT_OWNER

    creationDate              The date the user was created in the system.  Expressed as a Unix timestamp value.

    activeSessionCount        The number of active sessions for the user in the system.

    lastActivity              The date and time of last activity.  Expressed as a Unix timestamp value.

*/

  function get_user_list
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  function get_user_settings

  API Entry Point: getUserSettings

  The get_user_settings allows a client application to retrieve the user's settings.

  Embedded parameter values:

    There are no required parameters.

  The JSON object returned by this function contains the following properties:

    username                  The user's username.

    firstName                 The user's first name.

    middleName                The user's middle name.

    lastName                  The user's last name.

    emailAddress              The user's email address.

    accountType               The account type.  Valid values are:

                                AT_USER
                                AT_EVALUATOR
                                AT_OWNER

    sessionInactivityLimit    The inactivity limit, expressed in seconds.  A user session that exceedes the inactivity limit will
                              be terminated.

    sessionLimit              The limit on the number of concurrently active sessions the user may create.

    authMethod                The users's authorization method. Valid values are:

                                AM_PASSWORD
                                AM_AUTH_CODE
                                AM_LOGIC_URL

    defaultTimezone           The user's default timezone (e.g. America/Los_Angeles).

    accountStatus             The user account status.  Possible values are:

                                AS_ACTIVE
                                AS_LOCKED
                                AS_UNCONFIRMED
                                AS_CHANGE_PASSWORD

*/

  function get_user_settings
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  procedure recover_username

  API Entry Point: recoverUsername

  The recover_username procedure allows a user to submit a request to recover their username.  If the email address supplied by the
  user is registered in AsterionDB, a recovery email with the user's username will be sent.

  This procedure requires outbound SMTP Email support to be enabled.

  Embedded parameter values:

    emailAddress              The user's email address.

  Possible exceptions returned:

    error_logging.FEATURE_DISABLED
    error_logging.INVALID_PARAMETERS

*/

  procedure recover_username
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure reset_password

  API Entry Point: resetPassword

  The reset_password procedure allows a client application to process a user's request to reset their password.  This function is
  called after the user has received a reset token from a call to restapi.generate_password_reset_token.

  Embedded parameter values:

    confirmationToken         The confirmation token generated by restapi.generate_password_reset_token.

    newPassword               The user's new password.

*/

  procedure reset_password
  (
    p_json_parameters                 json_object_t
  );

  /*

  procedure terminate_user_session

  API Entry Point: terminateUserSession

  The terminate_user_session procedure allows a user application to process a logout request.

  Embedded parameter values:

    There are no required parameters.

*/

  procedure terminate_user_session
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure toggle_account_status

  API Entry Point: toggleAccountStatus

  The toggle_account_status procedure allows a system administrator to toggel a user's account status between locked to unlocked.

  This procedure can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    username                  The user whose account status will be toggled.

*/

  procedure toggle_account_status
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure update_user_info

  API Entry Point: updateUserInfo

  The update_user_info procedure allows a client application to update a user's information.

  Embedded parameter values:

    firstName                 The user's first name.

    middleName                The user's middle name/initial.

    lastName                  The user's last name.

*/

  procedure update_user_info
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure update_user_preferences

  API Entry Point: updateUserPreferences

  The update_user_preferences procedure allows a client application to update a user's preferences.

  Embedded parameter values:

    autoQueryEnabled          The value of the autoQueryEnabled, which maps to object_vault_users.auto_query_enabled.

    authMethod                The users's authorization method. Valid values are:

                                AM_PASSWORD
                                AM_AUTH_CODE
                                AM_LOGIC_URL

    defaultTimezone           The user's default timezone (e.g. America/Los_Angeles).

    concurrentFileUploads     The number of files to be upload simultaneously via the web interface.

    immutableUponCreation     This flag determines whether an object is flagged as immutable upon creation.

*/

  procedure update_user_preferences
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure update_user_properties

  API Entry Point: updateUserProperties

  The update_user_properties procedure allows a system administrator to update a user's properties.

  This procedure can only be called by a user session that has been created by a system administrator.

  Embedded parameter values:

    username                  The username of the AsterionDB user whose properties are to be updated.


    sessionInactivityLimit    The inactivity limit, expressed in seconds.  A user session that exceedes the inactivity limit will
                              be terminated.

    sessionLimit              The limit on the number of concurrently active sessions the user may create.

*/

  procedure update_user_properties
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure validate_change_email_code

  API Entry Point: validateChangeEmailCode

  The validate_change_email_code will validate the specified confirmation code and if valid, the user's email
  address will be set to the value specified when the confirmation code was created (by a call to send_change_email_code).

  Embedded parameter values:

    confirmationCode          The confirmation code sent by send_change_email_code to the user's new email address.

*/

  procedure validate_change_email_code
  (
    p_json_parameters                 json_object_t
  );

/*

  function validate_login_authorization

  API Entry Point: validateLoginAuthorization

  The validate_login_authorization will validate the specified login authorization code or url token and, if valid,
  the session activation process will continue.

  Embedded parameter values:

    confirmationToken         The login authorization code or url token that was sent to the user

  Embedded values in the returned JSON object:

    sessionId                 The user's session_id value.

    sessionStatus             The user session's status.  Possible values are:

                                SS_ACTIVE - all API features available

                                SS_SESSION_LIMIT - logon successful but restricted due to session limit

                                SS_CHANGE_PASSWORD - logon successful but user is required to change their
                                password

                              For a session that is restricted due to a session limit, the client application should issue calls to
                              restapi.get_active_sessions to get a list of active sessions and then call
                              restapi.activate_blocked_session or restapi.terminate_session depending
                              upon the action to be taken.

                              For a session that is restricted due to a password reset requirement, the client application must
                              present a screen, collect the appropriate input values and call restapi.change_password.

    apiUserId                 An externally accessible ID value that identifies the user.

    username                  The logged in user's name.

    firstName                 The user's first name.

    middleName                The user's middle name/initial.

    lastName                  The user's last name.

    emailAddress              The user's primary email address.

    accountType               The account type.  Valid values are:

                                AT_USER
                                AT_EVALUATOR
                                AT_OWNER

    autoQueryEnabled          The value of the autoQueryEnabled, which maps to object_vault_users.auto_query_enabled.

    defaultTimezone           The user's default timezone (e.g. America/Los_Angeles).

    authMethod                The users's authorization method. Valid values are:

                                AM_PASSWORD
                                AM_AUTH_CODE
                                AM_LOGIC_URL

    grantedPermissions        The grantedPermissions value is a JSON array containing the following key/value pairs:

                                permission        The permission granted to the user.
                                permissionClass   The class/group of permissions that the permission is a part of.

    termsAccepted             A flag indicating whether the user has affirmatively checked the 'terms accepted' checkbox.

    concurrentFileUploads     The number of files that will simultaneously be uploaded by the web-app.

*/

  function validate_login_authorization
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  procedure validate_new_email_address

  API Entry Point: validateNewEmailAddress

  The validate_new_email_address procedure allows a client application to validate a new user's email address as part of the self
  enrollment or enrollment by invitation workflow.  Validation will ensure that the email address does not already exist in the
  system.

  Embedded parameter values:

    emailAddress              The new user's email address.

  Possible exceptions returned:

    error_logging.EMAIL_ADDRESS_EXISTS

*/

  procedure validate_new_email_address
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure validate_new_username

  API Entry Point: validateNewUsername

  The validate_new_username procedure allows a new user's username to be validated as part of the workflow for user enrollment.
  Calling this procedure after a new username is specified (e.g. before creating a user) allows the UI to inform the user if the
  desired username is available.

  Embedded parameter values:

    username                  The new user's username.

  Possible exceptions returned:

    error_logging.USERNAME_TAKEN

*/

  procedure validate_new_username
  (
    p_json_parameters                 json_object_t
  );

/*

  procedure validate_session

  API Entry Point: -- none --

  This procedure is used by DbTwig to check session validation for every API call.

  This procedure is not callable directly by client applications.

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
