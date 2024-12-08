create or replace
package body icam as

  ACTION_DISALLOWED                   constant pls_integer := -20011;
  ACTION_DISALLOWED_EMSG              constant varchar2(35) := 'The requested action is not allowed';

  NOT_A_SITE_ADMIN                    constant pls_integer := -20005;
  NOT_A_SITE_ADMIN_EMSG               constant varchar2(48) := 'Privileged call made by a non site-administrator';

  ACTIVE_USER_SESSION                 constant pls_integer := -20000;
  ACTIVE_USER_SESSION_EMSG            constant varchar2(40) := 'There is an active session for this user';

  SESSION_TIMEOUT                     constant pls_integer := -20002;
  SESSION_TIMEOUT_EMSG                constant varchar2(26) := 'This session has timed out';

  SESSION_IP_MISMATCH                 constant pls_integer := -20007;
  SESSION_IP_MISMATCH_EMSG            constant varchar2(33) := 'Session IP addresses do not match';

  INVALID_SESSION_STATUS              constant pls_integer := -20014;
  INVALID_SESSION_STATUS_EMSG         constant varchar2(44) := 'An unexpected session status was encountered';

  INVALID_SESSION_ID                  constant pls_integer := -20003;
  INVALID_SESSION_ID_EMSG             constant varchar2(25) := 'The session ID is invalid';

  SESSION_USER_AGENT_MISMATCH         constant pls_integer := -20008;
  SESSION_USER_AGENT_MISMATCH_EMSG    constant varchar2(32) := 'Session user-agents do not match';

  INVALID_CONFIRMATION_DATA           constant pls_integer := -20116;     -- Tied to JavaScript application.  Do not change value.
  INVALID_CONFIRMATION_DATA_EMSG      constant varchar2(34) := 'The confirmation data is not valid';

  EMAIL_ADDRESS_EXISTS                constant pls_integer := -20117;     -- Tied to JavaScript application.  Do not change value.
  EMAIL_ADDRESS_EXISTS_EMSG           constant varchar2(45) := 'The email address has already been registered';

  USERNAME_TAKEN                      constant pls_integer := -20118;     -- Tied to JavaScript application.  Do not change value.
  USERNAME_TAKEN_EMSG                 constant varchar2(36) := 'This username has already been taken';

  INVALID_EMAIL_ADDRESS               constant pls_integer := -20119;
  INVALID_EMAIL_ADDRESS_EMSG          constant varchar2(39) := 'The email address is invalid or unknown';

  NEW_OLD_PASSWORDS_MATCH             constant pls_integer := -20120;
  NEW_OLD_PASSWORDS_MATCH_EMSG        constant varchar2(35) := 'The new and the old passwords match';

  CHANGE_PASSWORD_FAILED              constant pls_integer := -20121;
  CHANGE_PASSWORD_FAILED_EMSG         constant varchar2(44) := 'You did not enter your password in correctly';

  UNABLE_TO_TERMINATE                 constant pls_integer := -20122;
  UNABLE_TO_TERMINATE_EMSG            constant varchar2(29) := 'Unable to terminate a session';

  UNBLOCK_SESSION_FAILED              constant pls_integer := -20123;
  UNBLOCK_SESSION_FAILED_EMSG         constant varchar2(30) := 'Unblocking of a session failed';

  USER_OR_PASSWORD                    constant pls_integer := -20124;
  USER_OR_PASSWORD_EMSG               constant varchar2(35) := 'The username or password is invalid';

  ACCOUNT_STATUS                      constant pls_integer := -20125;
  ACCOUNT_STATUS_EMSG                 constant varchar2(25) := 'Invalid account status - ';

  PASSWORD_REQUIRED                   constant pls_integer := -20134;
  PASSWORD_REQUIRED_EMSG              constant varchar2(28) := 'A password value is required';

  OWNER_ALREADY_EXISTS                constant pls_integer := -20141;
  OWNER_ALREADY_EXISTS_EMSG           constant varchar2(58) := 'The owner of this installation has already been registered';

  INVALID_INVITATION_TOKEN            constant pls_integer := -20133;
  INVALID_INVITATION_TOKEN_EMSG       constant varchar2(55) := 'The invitation link is either invalid or it has expired';

  WEBAPP_CLIENT                       constant varchar2(12) := 'webAppClient';
  API_CLIENT                          constant varchar2(9) := 'apiClient';

/*

Copyright 2014 - 2019 by Asterion DB, LLC.

All rights reserved.

*/

  mfa_timeout_limit                   constant number(5) := 300;          -- 5 minutes...

  function at_session_limit
  (
    p_user_id                         icam_users.user_id%type,
    p_session_limit                   icam_users.session_limit%type,
    p_client_type                     icam_sessions.client_type%type
  )
  return boolean

  is

    l_active_sessions                 number(4);

  begin

    select  count(*)
      into  l_active_sessions
      from  icam_sessions
     where  session_status = SS_ACTIVE
       and  client_type = p_client_type
       and  user_id = p_user_id;

    if p_session_limit <= l_active_sessions then

      return true;

    else

      return false;

    end if;

  end at_session_limit;

  function found_timed_out_session
  (
    p_user_id                         icam_users.user_id%type,
    p_client_type                     icam_sessions.client_type%type,
    p_new_session_id                  icam_sessions.session_id%type
  )
  return boolean

  is

    l_active_session_id               icam_sessions.session_id%type;

  begin

    select  session_id
      into  l_active_session_id
      from  icam_sessions
     where  session_status = SS_ACTIVE
       and  client_type = p_client_type
       and  user_id = p_user_id
       and  ( (cast(systimestamp at time zone 'utc' as date) - cast(last_activity as date)) *
              db_twig.SECONDS_PER_DAY) > session_inactivity_limit
       and  rownum = 1;

    update  icam_sessions
       set  session_ended = systimestamp at time zone 'utc',
            session_disposition = SD_TIMEOUT,
            session_status = SS_TERMINATED,
            terminator_id = p_new_session_id
     where  session_id = l_active_session_id;

    return true;

  exception

  when no_data_found then

    return false;

  end found_timed_out_session;

  procedure check_header_info
  (
    p_session_id                      icam_sessions.session_id%type,
    p_session_address                 icam_sessions.client_address%type,
    p_client_address                  icam_sessions.client_address%type,
    p_session_user_agent              icam_sessions.user_agent%type,
    p_client_user_agent               icam_sessions.user_agent%type
  )

  is

  begin

    if p_session_address != p_client_address and '127.0.0.1' != p_client_address then

      terminate_session_with_error(p_session_id, SESSION_IP_MISMATCH, SESSION_IP_MISMATCH_EMSG);

    end if;

    if p_session_user_agent != p_client_user_agent then

      terminate_session_with_error(p_session_id, SESSION_USER_AGENT_MISMATCH, SESSION_USER_AGENT_MISMATCH_EMSG);

    end if;

  end check_header_info;

  function create_confirmation_token
  (
    p_user_id                         icam_users.user_id%type,
    p_purpose                         confirmation_tokens.purpose%type,
    p_expiration_date                 confirmation_tokens.expiration_date%type,
    p_client_address                  confirmation_tokens.client_address%type default null,
    p_email_address                   confirmation_tokens.email_address%type default null,
    p_session_id                      icam_sessions.session_id%type default null
  )
  return confirmation_tokens.confirmation_token%type

  is

    l_confirmation_token              confirmation_tokens.confirmation_token%type;

  begin

    l_confirmation_token := dbms_random.string('x', get_column_length('CONFIRMATION_TOKENS', 'CONFIRMATION_TOKEN'));

    insert into confirmation_tokens
      (confirmation_token, user_id, purpose, creation_date, expiration_date, client_address, email_address, session_id)
    values
      (l_confirmation_token, p_user_id, p_purpose, systimestamp at time zone 'utc', p_expiration_date, p_client_address,
       p_email_address, p_session_id);

    return l_confirmation_token;

  end create_confirmation_token;

/*
  function create_file_upload_client_session
  (
    p_user_id                         icam_users.user_id%type,
    p_session_inactivity_limit        icam_sessions.session_inactivity_limit%type,
    p_client_address                  icam_sessions.client_address%type,
    p_user_agent                      icam_sessions.user_agent%type,
    p_client_type                     icam_sessions.client_type%type
  )
  return clob

  is

    l_session_id                      icam_sessions.session_id%type;
    l_session_status                  icam_sessions.session_status%type;
    l_clob                            clob;

  begin

    l_session_id := dbms_random.string('x', digital_bunker.get_column_length('USER_SESSIONS', 'SESSION_ID'));
    l_session_status := SESSION_ACTIVE;

    insert into icam_sessions
      (session_id, user_id, client_address, session_created, last_activity, session_inactivity_limit,
       user_agent, session_status, client_type)
    values
      (l_session_id, p_user_id, p_client_address, systimestamp at time zone 'utc', systimestamp at time zone 'utc',
       p_session_inactivity_limit, p_user_agent, l_session_status, p_client_type);

    select  json_object(
              'sessionId' is s.session_id,
              'sessionStatus' is session_status,
              'firstName' is first_name,
              'lastName' is last_name)
      into  l_clob
      from  icam_sessions s, icam_users u
     where  s.user_id = icam.get_session_user_id(l_session_id)
       and  s.session_id = l_session_id
       and  s.user_id = u.user_id;

    return l_clob;

  end create_file_upload_client_session;
*/

  function create_webapp_client_session
  (
    p_user_id                         icam_users.user_id%type,
    p_session_limit                   icam_users.session_limit%type,
    p_session_inactivity_limit        icam_sessions.session_inactivity_limit%type,
    p_account_status                  icam_users.account_status%type,
    p_client_address                  icam_sessions.client_address%type,
    p_user_agent                      icam_sessions.user_agent%type,
    p_auth_method                     icam_users.auth_method%type
  )
  return clob

  is

    l_session_id                      icam_sessions.session_id%type;
    l_session_status                  icam_sessions.session_status%type := null;
    l_session_inactivity_limit        icam_sessions.session_inactivity_limit%type := p_session_inactivity_limit;

  begin

    l_session_id := dbms_random.string('x', get_column_length('ICAM_SESSIONS', 'SESSION_ID'));

    if AS_CHANGE_PASSWORD = p_account_status then

      l_session_status := SS_CHANGE_PASSWORD;

    end if;

    if l_session_status is null and AM_AUTH_CODE = p_auth_method then

      l_session_status := SS_AUTH_CODE;
      l_session_inactivity_limit := mfa_timeout_limit;

    end if;

    if l_session_status is null and AM_LOGIN_URL = p_auth_method then

      l_session_status := SS_LOGIN_URL;
      l_session_inactivity_limit := mfa_timeout_limit;

    end if;

    if l_session_status is null and at_session_limit(p_user_id, p_session_limit, WEBAPP_CLIENT) then

      l_session_status := SS_SESSION_LIMIT;

    end if;

    if l_session_status is null then

      l_session_status := SS_ACTIVE;

    end if;

    insert into icam_sessions
      (session_id, user_id, client_address, session_created, last_activity, session_inactivity_limit,
       user_agent, session_status, client_type)
    values
      (l_session_id, p_user_id, p_client_address, systimestamp at time zone 'utc', systimestamp at time zone 'utc',
       l_session_inactivity_limit, p_user_agent, l_session_status, WEBAPP_CLIENT);

    if l_session_status = SS_SESSION_LIMIT and found_timed_out_session(p_user_id, WEBAPP_CLIENT, l_session_id) then

      update  icam_sessions
         set  session_status = SS_ACTIVE
       where  session_id = l_session_id;

    end if;

    if SS_AUTH_CODE = l_session_status then

      raise_application_error(-20000, 'email_send_auth_code');

/*      email.send_auth_code(p_user_id, create_confirmation_token(p_user_id => p_user_id,
        p_purpose => 'auth code', p_expiration_date => systimestamp at time zone 'utc' + mfa_timeout_limit / db_twig.SECONDS_PER_DAY,
        p_client_address => p_client_address, p_session_id => l_session_id, p_token_length => 6)); */

    end if;

    if SS_LOGIN_URL = l_session_status then

      raise_application_error(-20000, 'email_send_auth_code');

/*      email.send_login_url(p_user_id, create_confirmation_token(p_user_id => p_user_id,
        p_purpose => 'login url', p_expiration_date => systimestamp at time zone 'utc' + mfa_timeout_limit / db_twig.SECONDS_PER_DAY,
        p_client_address => p_client_address, p_session_id => l_session_id)); */

    end if;

    return icam.get_session_info(l_session_id);

  end create_webapp_client_session;

  procedure update_last_activity
  (
    l_session_id                      icam_sessions.session_id%type
  )

  is

    PRAGMA AUTONOMOUS_TRANSACTION;

  begin

    update  icam_sessions
       set  last_activity = systimestamp at time zone 'utc'
     where  session_id = l_session_id;

    commit;

  end update_last_activity;

  procedure validate_identification_and_password
  (
    p_identification                  varchar2,
    p_txt_password                    varchar2,
    p_client_address                  icam_sessions.client_address%type
  )

  is

    PRAGMA AUTONOMOUS_TRANSACTION;

    l_valid                           varchar2(1);

  begin

    select  'Y'
      into  l_valid
      from  icam_users
     where  ( upper(username) = upper(p_identification) or upper(email_address) = upper(p_identification) )
       and  hashed_username_password = hashed_value(username||p_txt_password, random_bytes);

    insert into login_history
      (supplied_identification, success_or_failure, client_address)
    values
      (p_identification, 'success', p_client_address);

    commit;

  exception

  when no_data_found then

    insert into login_history
      (supplied_identification, success_or_failure, client_address)
    values
      (p_identification, 'failure', p_client_address);

    commit;

    raise_application_error(USER_OR_PASSWORD, USER_OR_PASSWORD_EMSG);

  end validate_identification_and_password;

---
---
---

  function abandon_for_current_session
  (
    p_session_id                      icam_sessions.session_id%type,
    p_session_to_terminate            icam_sessions.session_id%type
  )
  return clob

  is

    l_session_is_active               varchar2(1);
    l_json_object                     json_object_t := json_object_t;
    l_client_type                     icam_sessions.client_type%type;
    l_user_id                         icam_sessions.user_id%type;
    l_session_limit                   icam_users.session_limit%type;

  begin

    update  icam_sessions
       set  session_status = SS_TERMINATED,
            session_ended = systimestamp at time zone 'utc',
            session_disposition = SD_CANCELED,
            terminator_id = p_session_id
     where  session_id = p_session_to_terminate
       and  session_status in (SS_ACTIVE, SS_TERMINATED);

    if 1 != sql%rowcount then

      raise_application_error(UNABLE_TO_TERMINATE, UNABLE_TO_TERMINATE_EMSG);

    end if;

    select  s.user_id, client_type, session_limit
      into  l_user_id, l_client_type, l_session_limit
      from  icam_sessions s, icam_users u
     where  session_id = p_session_id
       and  s.user_id = u.user_id;

    if at_session_limit(l_user_id, l_session_limit, l_client_type) then

      raise_application_error(UNBLOCK_SESSION_FAILED, UNBLOCK_SESSION_FAILED_EMSG);

    end if;

    update  icam_sessions
       set  session_status = SS_ACTIVE
     where  session_id = p_session_id
       and  session_status = SS_SESSION_LIMIT;

    if 1 != sql%rowcount then

      raise_application_error(UNBLOCK_SESSION_FAILED, UNBLOCK_SESSION_FAILED_EMSG);

    end if;

    l_json_object.put('sessionStatus', SS_ACTIVE);
    return l_json_object.to_clob;

  end abandon_for_current_session;

  function activate_blocked_session
  (
    p_blocked_session_id              icam_sessions.session_id%type,
    p_blocked_client_address          icam_sessions.client_address%type,
    p_blocked_user_agent              icam_sessions.user_agent%type
  )
  return clob

  is

    l_session_limit                   icam_users.session_limit%type;
    l_active_sessions                 number(4);
    l_active_session_id               icam_sessions.session_id%type;
    l_user_id                         icam_users.user_id%type;
    l_client_address                  icam_sessions.client_address%type;
    l_user_agent                      icam_sessions.user_agent%type;
    l_last_activity_in_seconds        number(9);
    l_session_inactivity_limit        icam_sessions.session_inactivity_limit%type;
    l_clob                            clob;

  begin

    begin

      select  ( cast(systimestamp at time zone 'utc' as date) - cast(last_activity as date)) * db_twig.SECONDS_PER_DAY,
              s.session_inactivity_limit, session_limit, s.user_id, client_address, user_agent
        into  l_last_activity_in_seconds, l_session_inactivity_limit, l_session_limit, l_user_id, l_client_address, l_user_agent
        from  icam_sessions s, icam_users u
       where  session_id = p_blocked_session_id
         and  s.user_id = u.user_id
         and  session_status in (SS_CHANGE_PASSWORD, SS_SESSION_LIMIT);

      if l_last_activity_in_seconds > l_session_inactivity_limit then

        terminate_session_with_error(p_blocked_session_id, SESSION_TIMEOUT, SESSION_TIMEOUT_EMSG);

      end if;

      if l_client_address != p_blocked_client_address then

        terminate_session_with_error(p_blocked_session_id, SESSION_IP_MISMATCH, SESSION_IP_MISMATCH_EMSG);

      end if;

      if l_user_agent != p_blocked_user_agent then

        terminate_session_with_error(p_blocked_session_id, SESSION_USER_AGENT_MISMATCH, SESSION_USER_AGENT_MISMATCH_EMSG);

      end if;

    exception

    when no_data_found then

      raise_application_error(INVALID_SESSION_ID, INVALID_SESSION_ID_EMSG);

    end;

    select  count(*)
      into  l_active_sessions
      from  icam_sessions
     where  session_status = SS_ACTIVE
       and  client_type = WEBAPP_CLIENT
       and  user_id = l_user_id;

    if l_session_limit <= l_active_sessions then

      begin

        select  session_id
          into  l_active_session_id
          from  icam_sessions
         where  session_status = SS_ACTIVE
           and  client_type = WEBAPP_CLIENT
           and  user_id = l_user_id
           and  ( (cast(systimestamp at time zone 'utc' as date) - cast(last_activity as date)) *
                  db_twig.SECONDS_PER_DAY) > session_inactivity_limit
           and  rownum = 1;

        update  icam_sessions
           set  session_status = SS_ACTIVE
         where  session_id = p_blocked_session_id;

        update  icam_sessions
           set  session_ended = systimestamp at time zone 'utc',
                session_disposition = SD_TIMEOUT,
                session_status = SS_TERMINATED,
                terminator_id = p_blocked_session_id
         where  session_id = l_active_session_id;

      exception

      when no_data_found then

        select  json_object('sessionStatus' is session_status)
          into  l_clob
          from  icam_sessions
         where  session_id = p_blocked_session_id;

        return l_clob;

      end;

    else

      update  icam_sessions
         set  session_status = SS_ACTIVE
       where  session_id = p_blocked_session_id;

    end if;

    select  json_object('sessionStatus' is SS_ACTIVE)
      into  l_clob
      from  dual;

    return l_clob;

  end activate_blocked_session;

  procedure change_password
  (
    p_user_id                         icam_users.user_id%type,
    p_client_address                  password_history.client_address%type,
    p_current_password                varchar2,
    p_new_password                    varchar2
  )

  is

    l_hashed_username_password        icam_users.hashed_username_password%type;
    l_username                        icam_users.username%type;
    l_random_bytes                    icam_users.random_bytes%type;

  begin

    select  hashed_username_password, username, random_bytes
      into  l_hashed_username_password, l_username, l_random_bytes
      from  icam_users
     where  user_id = p_user_id;

    if l_hashed_username_password != hashed_value(l_username||p_current_password, l_random_bytes) then

      raise_application_error(CHANGE_PASSWORD_FAILED, CHANGE_PASSWORD_FAILED_EMSG);

    end if;

    if l_hashed_username_password = hashed_value(l_username||p_new_password, l_random_bytes) then

      raise_application_error(NEW_OLD_PASSWORDS_MATCH, NEW_OLD_PASSWORDS_MATCH_EMSG);

    end if;

    update  icam_users
       set  hashed_username_password = hashed_value(l_username||p_new_password, l_random_bytes),
            account_status = AS_ACTIVE
     where  user_id = p_user_id;

    insert into password_history
      (user_id, change_made_by, old_hashed_username_password, replacement_method, client_address)
    values
      (p_user_id, p_user_id, l_hashed_username_password, 'password changed by user', p_client_address);

  end change_password;

  procedure change_system_password
  (
    p_new_password                    varchar2
  )

  is

    l_hashed_username_password        icam_users.hashed_username_password%type;
    l_user_id                         icam_users.user_id%type;
    l_random_bytes                    icam_users.random_bytes%type;
    l_username                        icam_users.username%type;

  begin

    select  user_id, hashed_username_password, random_bytes, username
      into  l_user_id, l_hashed_username_password, l_random_bytes, l_username
      from  icam_users
     where  account_type = AT_ADMINISTRATOR;

    update  icam_users
       set  hashed_username_password = hashed_value(l_username||p_new_password, l_random_bytes)
     where  user_id = l_user_id;

    insert into password_history
      (user_id, change_made_by, old_hashed_username_password, replacement_method, client_address)
    values
      (l_user_id, l_user_id, l_hashed_username_password, 'password changed by owner', sys_context('userenv', 'ip_address'));

  end change_system_password;

  function confirm_new_user
  (
    p_identification                  icam_users.email_address%type,
    p_txt_password                    varchar2,
    p_client_address                  icam_sessions.client_address%type,
    p_user_agent                      icam_sessions.user_agent%type,
    p_confirmation_token              confirmation_tokens.confirmation_token%type
  )
  return clob

  is

    l_expiration_date                 confirmation_tokens.expiration_date%type;
    l_user_id                         icam_users.user_id%type;
    l_account_status                  icam_users.account_status%type;
    l_json_object                     json_object_t := json_object_t;

  begin

    validate_confirmation_token(p_confirmation_token);

    select  user_id, account_status
      into  l_user_id, l_account_status
      from  icam_users
     where  upper(username) = upper(p_identification) or upper(email_address) = upper(p_identification);

    if AS_UNCONFIRMED != l_account_status then

      raise_application_error(INVALID_CONFIRMATION_DATA, INVALID_CONFIRMATION_DATA_EMSG);

    end if;

    update  icam_users
       set  account_status = AS_ACTIVE
     where  user_id = l_user_id;

    insert into account_status_history
      (user_id, prior_status, transition_date, transition_reason)
    values
      (l_user_id, l_account_status, systimestamp at time zone 'utc', 'New account confirmation');

    return create_user_session(p_identification, p_txt_password, p_client_address, p_user_agent);

  exception

  when no_data_found then

    raise_application_error(INVALID_CONFIRMATION_DATA, INVALID_CONFIRMATION_DATA_EMSG);

  end confirm_new_user;

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
  return icam_users.user_id%type

  is

    l_constraint_name                 user_cons_columns.constraint_name%type;

    l_user_id                         icam_users.user_id%type;
    l_random_bytes                    icam_users.random_bytes%type := dbms_crypto.randombytes(get_column_length('ICAM_USERS', 'RANDOM_BYTES'));

  begin

    if p_txt_password is null then

      raise_application_error(PASSWORD_REQUIRED, PASSWORD_REQUIRED_EMSG);

    end if;

    begin

      insert into icam_users
        (user_id, username, hashed_username_password, random_bytes, first_name, middle_name, last_name, email_address,
         account_status, account_type, default_timezone)
      values
        (id_seq.nextval, p_username, hashed_value(p_username||p_txt_password, l_random_bytes),
         l_random_bytes, p_first_name, p_middle_name, p_last_name, p_email_address, AS_ACTIVE, AT_ADMINISTRATOR,
         p_default_timezone)
      returning user_id into l_user_id;

    exception

    when dup_val_on_index then

      l_constraint_name := substr(sqlerrm,instr(sqlerrm, '.') + 1, instr(sqlerrm, ')') - instr(sqlerrm, '.') - 1);

      if l_constraint_name = 'ICAM_USER_IX' then

        raise_application_error(USERNAME_TAKEN, USERNAME_TAKEN_EMSG);

      end if;

      if l_constraint_name = 'ICAM_EMAIL_IX' then

        raise_application_error(EMAIL_ADDRESS_EXISTS, EMAIL_ADDRESS_EXISTS_EMSG);

      end if;

    end;

    return l_user_id;

  end create_administrator_account;

  procedure create_api_client_session
  (
    p_api_client_token                icam_sessions.session_id%type,
    p_old_client_token                icam_sessions.session_id%type,
    p_json_parameters                 json_object_t
  )

  is

    l_user_id                         icam_sessions.user_id%type := get_session_user_id_from_json(p_json_parameters);
    l_user_agent                      icam_sessions.user_agent%type := db_twig.get_string_parameter(p_json_parameters, 'userAgent');

  begin

    if p_old_client_token is not null then

      update  icam_sessions
         set  session_status = SS_TERMINATED,
              session_disposition = SD_CANCELED,
              session_ended = systimestamp at time zone 'utc'
       where  session_id = p_old_client_token;

    end if;

    insert into icam_sessions
      (session_id, user_id, client_address, session_created, last_activity, session_inactivity_limit,
       user_agent, session_status, client_type)
    values
      (p_api_client_token, l_user_id, '127.0.0.1', systimestamp at time zone 'utc', systimestamp at time zone 'utc',
       -1, l_user_agent, AS_ACTIVE, API_CLIENT);

  end create_api_client_session;

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
  return clob

  is

    l_password                        varchar2(30) := icam.generate_temporary_password(p_caller_session_id, p_client_address, p_username);
    l_user_id                         icam_users.user_id%type;
    l_result                          json_object_t := json_object_t;
    l_constraint_name                 user_cons_columns.constraint_name%type;
    l_random_bytes                    icam_users.random_bytes%type := dbms_crypto.randombytes(get_column_length('ICAM_USERS', 'RANDOM_BYTES'));

  begin


    begin

      insert into icam_users
        (user_id, username, hashed_username_password, random_bytes, first_name, middle_name, last_name, email_address,
         account_status, account_type, default_timezone)
      values
        (id_seq.nextval, p_username, hashed_value(p_username||l_password, l_random_bytes),
         l_random_bytes, p_first_name, p_middle_name, p_last_name, p_email_address, AS_ACTIVE, AT_USER,
         p_default_timezone)
      returning user_id into l_user_id;

    exception

    when dup_val_on_index then

      l_constraint_name := substr(sqlerrm,instr(sqlerrm, '.') + 1, instr(sqlerrm, ')') - instr(sqlerrm, '.') - 1);

      if l_constraint_name = 'ICAM_USER_IX' then

        raise_application_error(USERNAME_TAKEN, USERNAME_TAKEN_EMSG);

      end if;

      if l_constraint_name = 'ICAM_EMAIL_IX' then

        raise_application_error(EMAIL_ADDRESS_EXISTS, EMAIL_ADDRESS_EXISTS_EMSG);

      end if;

    end;

    l_result.put('userId', l_user_id);
    l_result.put('temporaryPassword', l_password);
    return l_result.to_clob;

  end create_user_account;

  function create_user_session
  (
    p_identification                  varchar2,
    p_txt_password                    varchar2,
    p_client_address                  icam_sessions.client_address%type,
    p_user_agent                      icam_sessions.user_agent%type
  )
  return clob

  is

    l_user_id                         icam_users.user_id%type;
    l_account_status                  icam_users.account_status%type;
    l_session_limit                   icam_users.session_limit%type;
    l_last_activity_in_seconds        number(9);
    l_session_inactivity_limit        icam_sessions.session_inactivity_limit%type;
    l_active_sessions                 number(4);
    l_username                        icam_users.username%type;
    l_session_status                  icam_sessions.session_status%type;
    l_clob                            clob;
    l_auth_method                     icam_users.auth_method%type;
    l_json_object                     json_object_t;

  begin

    validate_identification_and_password(p_identification, p_txt_password, p_client_address);

    select  user_id, account_status, session_inactivity_limit, session_limit,
            auth_method
      into  l_user_id, l_account_status, l_session_inactivity_limit, l_session_limit,
            l_auth_method
      from  icam_users
     where  upper(username) = upper(p_identification)
        or  upper(email_address) = upper(p_identification);

    if AS_ACTIVE != l_account_status and AS_CHANGE_PASSWORD != l_account_status then

      raise_application_error(ACCOUNT_STATUS, ACCOUNT_STATUS_EMSG||' '||l_account_status);

    end if;

    return create_webapp_client_session(l_user_id, l_session_limit, l_session_inactivity_limit,
      l_account_status, p_client_address, p_user_agent, l_auth_method);

/*
    if restapi.WEBAPP_CLIENT = p_client_type then

      return create_webapp_client_session(l_user_id, l_session_limit, l_session_inactivity_limit,
        l_account_status, p_client_address, p_user_agent, p_client_type, l_auth_method);

    end if;

    if restapi.FILE_UPLOAD_CLIENT = p_client_type then

      return create_file_upload_client_session(l_user_id, l_session_inactivity_limit,
        p_client_address, p_user_agent, p_client_type);

    end if;
*/

  end create_user_session;

  function extract_email_domain
  (
    p_email_address                   icam_users.email_address%type
  )
  return varchar2

  deterministic

  is

  begin

    return substr(p_email_address, instr(p_email_address, '@') + 1);

  end extract_email_domain;

  function extract_session_id
  (
    p_json_object                     json_object_t
  )
  return icam_sessions.session_id%type

  is

    l_session_id                      icam_sessions.session_id%type;

  begin

    l_session_id := p_json_object.get_string('sessionId');
    return l_session_id;

  end extract_session_id;

  procedure generate_password_reset_token
  (
    p_email_address                   icam_users.email_address%type,
    p_client_address                  confirmation_tokens.client_address%type
  )

  is

    l_confirmation_token              confirmation_tokens.confirmation_token%type;
    l_user_id                         icam_users.user_id%type;
    l_first_name                      icam_users.first_name%type;
    l_middle_name                     icam_users.middle_name%type;
    l_last_name                       icam_users.last_name%type;
    l_account_status                  icam_users.account_status%type;

  begin

    begin

      select  user_id, first_name, middle_name, last_name, account_status
        into  l_user_id, l_first_name, l_middle_name, l_last_name, l_account_status
        from  icam_users
       where  upper(email_address) = upper(p_email_address);

      if AS_ACTIVE = l_account_status then

        l_confirmation_token := create_confirmation_token(p_user_id => l_user_id, p_purpose => 'password reset',
          p_expiration_date => systimestamp at time zone 'utc' + 1, p_client_address => p_client_address);
-- TODO        email.send_reset_password_email(l_first_name||' '||l_middle_name||' '||l_last_name, p_email_address, l_confirmation_token);

      end if;

    exception

    when no_data_found then

      null;

    end;

  end generate_password_reset_token;

  function generate_temporary_password
  (
    p_session_id                      icam_sessions.session_id%type,
    p_client_address                  icam_sessions.client_address%type,
    p_username                        icam_users.username%type
  )
  return varchar2

  is

    l_txt_password                    varchar2(10) := dbms_random.string('x', 10);

  begin

--  Note: this code still works even if no user has been created at the time of calling. The insert and update succeed
--  w/out error after inserting/updating zero rows.

    insert into password_history
      (user_id, change_made_by, old_hashed_username_password, replacement_method, client_address)
    select  user_id, get_session_user_id(p_session_id), hashed_username_password, 'new password generated', p_client_address
      from  icam_users
     where  username = p_username;

    update  icam_users
       set  account_status = AS_CHANGE_PASSWORD,
            hashed_username_password = hashed_value(username||l_txt_password, random_bytes)
     where  username = p_username;

    return l_txt_password;

  end generate_temporary_password;

  function get_active_session_count return pls_integer

  is

    l_active_session_count            pls_integer;

  begin

    select  count(*)
      into  l_active_session_count
      from  icam_sessions
     where  session_status = SS_ACTIVE
       and  client_type = WEBAPP_CLIENT;

    return l_active_session_count;

  end get_active_session_count;

  function get_active_session_count
  (
    p_user_id                         icam_users.user_id%type
  )
  return number

  is

    l_active_session_count            pls_integer;

  begin

    select  count(*)
      into  l_active_session_count
      from  icam_sessions
     where  session_status = SS_ACTIVE
       and  client_type = WEBAPP_CLIENT
       and  user_id = p_user_id;

    return l_active_session_count;

  end get_active_session_count;

  function get_active_sessions
  (
    p_user_id                         icam_users.user_id%type
  )
  return clob

  is

    l_result                          clob;
    l_rows                            pls_integer;

  begin

    select  count(*), json_object('activeSessions' is
            json_arrayagg(json_object(
              'lastActivity'    is db_twig.convert_timestamp_to_unix_timestamp(last_activity),
              'sessionId'       is session_id,
              'clientAddress'   is client_address,
              'sessionCreated'  is db_twig.convert_timestamp_to_unix_timestamp(session_created),
              'userAgent'       is user_agent)
              order by db_twig.convert_timestamp_to_unix_timestamp(last_activity)) returning clob)
      into  l_rows, l_result
      from  icam_sessions
     where  user_id = p_user_id
       and  session_status = SS_ACTIVE
       and  client_type = WEBAPP_CLIENT;

    if 0 = l_rows then

      return db_twig.empty_json_array('activeSessions');

    end if;

    return l_result;

  end get_active_sessions;

  function get_blocked_session_user_id
  (
    p_json_parameters                 json_object_t
  )
  return icam_users.user_id%type

  is

    l_session_id                      icam_sessions.session_id%type := extract_session_id(p_json_parameters);
    l_blocked_client_address          icam_sessions.client_address%type default null;
    l_blocked_user_agent              icam_sessions.user_agent%type default null;
    l_user_id                         icam_users.user_id%type;
    l_client_address                  icam_sessions.client_address%type;
    l_user_agent                      icam_sessions.user_agent%type;

  begin

    begin

      l_client_address := p_json_parameters.get_string('clientAddress');
      l_user_agent := p_json_parameters.get_string('userAgent');

      select  user_id, client_address, user_agent
        into  l_user_id, l_blocked_client_address, l_blocked_user_agent
        from  icam_sessions s
       where  session_id = l_session_id
         and  session_status = SS_SESSION_LIMIT;

      check_header_info(l_session_id, l_client_address, l_blocked_client_address, l_user_agent, l_blocked_user_agent);

    exception

    when no_data_found then

      raise_application_error(INVALID_SESSION_ID, INVALID_SESSION_ID_EMSG);

    end;

    return l_user_id;

  end get_blocked_session_user_id;

  function get_last_activity
  (
    p_user_id                         icam_users.user_id%type
  )
  return icam_sessions.last_activity%type

  is

    l_last_activity                   icam_sessions.last_activity%type;

  begin

    select  max(last_activity)
      into  l_last_activity
      from  icam_sessions
     where  user_id = p_user_id;

    return l_last_activity;

  end get_last_activity;

  function get_login_history
  (
    p_user_id                         icam_users.user_id%type
  )
  return clob

  is

    l_result                          clob;
    l_rows                            pls_integer;

  begin

    select  count(*), json_object('loginHistory' is
            json_arrayagg(json_object(
              'sessionCreated'      is db_twig.convert_timestamp_to_unix_timestamp(session_created),
              'clientAddress'       is client_address,
              'sessionStatus'       is session_status,
              'sessionDisposition'  is session_disposition,
              'userAgent'           is user_agent,
              'sessionEnded'        is db_twig.convert_timestamp_to_unix_timestamp(session_ended),
              'lastActivity'        is db_twig.convert_timestamp_to_unix_timestamp(last_activity),
              'terminatedBy'        is icam.get_terminated_by(terminator_id))
              order by db_twig.convert_timestamp_to_unix_timestamp(session_created) desc returning clob) returning clob)
      into  l_rows, l_result
      from  icam_sessions
     where  user_id = p_user_id
       and  client_type = WEBAPP_CLIENT;

    if 0 = l_rows then

      return db_twig.empty_json_array('loginHistory');

    end if;

    return l_result;

  end get_login_history;

  function get_session_info
  (
    p_session_id                      icam_sessions.session_id%type
  )
  return clob

  is

    l_webapp_session_info             clob;

  begin

    select  json_object(
              'sessionId' is session_id,
              'sessionStatus' is session_status,
              'firstName' is first_name,
              'middleName' is middle_name,
              'lastName' is last_name,
              'emailAddress' is email_address,
              'accountType' is account_type,
              'accountStatus' is account_status,
              'authMethod' is auth_method,
              'defaultTimezone' is default_timezone)
      into  l_webapp_session_info
      from  icam_sessions s, icam_users u
     where  s.user_id = icam.get_session_user_id(p_session_id)
       and  s.session_id = p_session_id
       and  s.user_id = u.user_id;

    return l_webapp_session_info;

  end get_session_info;

  function get_session_username
  (
    p_session_id                      icam_sessions.session_id%type
  )
  return icam_users.username%type

  is

    l_username                        icam_users.username%type;

  begin

    select  username
      into  l_username
      from  icam_users u, icam_sessions s
     where  session_id = p_session_id
       and  s.user_id = u.user_id;

    return l_username;

  exception

  when no_data_found then

    return null;

  end get_session_username;

  function get_session_user_id
  (
    p_session_id                      icam_sessions.session_id%type
  )
  return icam_users.user_id%type

  is

    l_user_id                         icam_users.user_id%type;

  begin

    begin

      select  user_id
        into  l_user_id
        from  icam_sessions s
       where  session_id = p_session_id;

    exception

    when no_data_found then

      raise_application_error(INVALID_SESSION_ID, INVALID_SESSION_ID_EMSG);

    end;

    return l_user_id;

  end get_session_user_id;

  function get_session_user_id_from_json
  (
    p_json_object                     json_object_t
  )
  return icam_users.user_id%type

  is

  begin

    return get_session_user_id(extract_session_id(p_json_object));

  end get_session_user_id_from_json;

  function get_session_user_id_from_json
  (
    p_json_parameters                 clob
  )
  return icam_users.user_id%type

  is

  begin

    return get_session_user_id(extract_session_id(json_object_t(p_json_parameters)));

  end get_session_user_id_from_json;

  function get_session_username
  (
    p_session_id                      icam_sessions.session_id%type,
    p_client_address                  icam_sessions.client_address%type,
    p_user_agent                      icam_sessions.user_agent%type

  )

  return icam_users.username%type

  is

    l_username                        icam_users.username%type;
    l_last_activity_in_seconds        number(9);
    l_session_inactivity_limit        icam_sessions.session_inactivity_limit%type;
    l_client_address                  icam_sessions.client_address%type;
    l_user_agent                      icam_sessions.user_agent%type;

  begin

    begin

      select  u.username, s.session_inactivity_limit, client_address, user_agent,
              ( cast(systimestamp at time zone 'utc' as date) - cast(last_activity as date)) * db_twig.SECONDS_PER_DAY
        into  l_username, l_session_inactivity_limit, l_client_address, l_user_agent, l_last_activity_in_seconds
        from  icam_sessions s, icam_users u
       where  session_id = p_session_id
         and  session_status = SS_ACTIVE
         and  s.user_id = u.user_id;

      if l_last_activity_in_seconds > l_session_inactivity_limit then

        raise_application_error(SESSION_TIMEOUT, SESSION_TIMEOUT_EMSG);

      end if;

      check_header_info(p_session_id, l_client_address, p_client_address, l_user_agent, p_user_agent);

    exception

    when no_data_found then

      raise_application_error(INVALID_SESSION_ID, INVALID_SESSION_ID_EMSG);

    end;

    return l_username;

  end get_session_username;

  function get_terminated_by
  (
    p_terminator_id                   icam_sessions.terminator_id%type
  )
  return icam_users.username%type

  is

    l_username                        icam_users.username%type;

  begin

    if p_terminator_id is null then

      return null;

    end if;

    select  username
      into  l_username
      from  icam_users u, icam_sessions s
     where  session_id = p_terminator_id
       and  s.user_id = u.user_id;

    return l_username;

  end get_terminated_by;

  function get_user_id
  (
    p_username                        icam_users.username%type
  )
  return icam_users.user_id%type

  is

    l_user_id                         icam_users.user_id%type;

  begin

    select  user_id
      into  l_user_id
      from  icam_users
     where  upper(username) = upper(p_username);

    return l_user_id;

  end get_user_id;

  function get_user_list return clob

  is

    l_result                          clob;

  begin

    select  json_arrayagg(json_object(
              'username'            is username,
              'emailAddress'        is email_address,
              'firstName'           is first_name,
              'middleName'          is middle_name,
              'lastName'            is last_name,
              'accountStatus'       is account_status,
              'accountType'         is account_type,
              'creationDate'        is db_twig.convert_timestamp_to_unix_timestamp(creation_date),
              'activeSessionCount'  is icam.get_active_session_count(user_id),
              'lastActivity'        is db_twig.convert_timestamp_to_unix_timestamp(icam.get_last_activity(user_id)))
              order by username returning clob)
      into  l_result
      from  icam_users;

    return l_result;

  end get_user_list;

  function get_user_settings
  (
    p_user_id                         icam_users.user_id%type
  )
  return clob

  is

    l_result                          clob;

  begin

    select  json_object(
            'username' is username,
            'firstName' is first_name,
            'middleName' is middle_name,
            'lastName' is last_name,
            'emailAddress' is email_address,
            'accountType' is account_type,
            'sessionInactivityLimit' is session_inactivity_limit,
            'sessionLimit' is session_limit,
            'authMethod' is auth_method,
            'defaultTimezone' is default_timezone,
            'accountStatus' is account_status)
      into  l_result
      from  icam_users u
     where  user_id = p_user_id;

    return l_result;

  end get_user_settings;

  function get_user_settings
  (
    p_username                        icam_users.username%type
  )
  return clob

  is

    l_user_id                         icam_users.user_id%type;

  begin

    select  user_id
      into  l_user_id
      from  icam_users
     where  upper(username) = upper(p_username);

    return get_user_settings(l_user_id);

  end get_user_settings;

  function hash_value_for_user
  (
    p_value_to_hash                   varchar2,
    p_user_id                         icam_users.user_id%type
  )
  return raw

  is

    l_random_bytes                    icam_users.random_bytes%type;

  begin

    select  random_bytes
      into  l_random_bytes
      from  icam_users
     where  user_id = p_user_id;

    return hashed_value(p_value_to_hash, l_random_bytes);

  end hash_value_for_user;

  function hashed_value
  (
    p_value_to_hash                   varchar2,
    p_random_bytes                    icam_users.random_bytes%type
  )
  return raw

  is

  begin

    return dbms_crypto.hash(utl_raw.cast_to_raw(p_value_to_hash)||p_random_bytes, dbms_crypto.hash_sh512);

  end hashed_value;

  procedure recover_username
  (
    p_email_address                   icam_users.email_address%type,
    p_client_address                  confirmation_tokens.client_address%type
  )

  is

    l_username                        icam_users.username%type;
    l_first_name                      icam_users.first_name%type;
    l_middle_name                     icam_users.middle_name%type;
    l_last_name                       icam_users.last_name%type;
    l_user_id                         icam_users.user_id%type := null;

  begin

    begin

      select  username, first_name, middle_name, last_name, user_id
        into  l_username, l_first_name, l_middle_name, l_last_name, l_user_id
        from  icam_users
       where  upper(email_address) = upper(p_email_address);

-- TODO      email.send_recovered_username_email(l_first_name||' '||l_middle_name||' '||l_last_name, p_email_address, l_username);

    exception

    when no_data_found then

      null;

    end;

  end recover_username;

  procedure remove_unconfirmed_users

  is

  begin

    for unconfirmed_user_row in
    (
      select  user_id
        from  icam_users
       where  account_status = AS_UNCONFIRMED
    )
    loop

      delete  /*+ no_parallel */
        from  confirmation_tokens
       where  user_id = unconfirmed_user_row.user_id;

    end loop;

    delete  /*+ no_parallel */
      from  icam_users
     where  account_status = AS_UNCONFIRMED;

  end remove_unconfirmed_users;

  procedure remove_user
  (
    p_user_id                         icam_users.user_id%type
  )

  is

    l_plsql_text                      varchar2(1024);
    l_active_sessions                 pls_integer;

  begin

    select  count(*)
      into  l_active_sessions
      from  icam_sessions
     where  session_status = SS_ACTIVE
       and  client_type = WEBAPP_CLIENT
       and  user_id = p_user_id;

    if 0 != l_active_sessions then

      raise_application_error(ACTIVE_USER_SESSION, ACTIVE_USER_SESSION_EMSG||' '||'Unable to remove user.');

    end if;

    delete  /*+ no_parallel */
      from  confirmation_tokens
     where  user_id = p_user_id;

    delete  /*+ no_parallel */
      from  icam_sessions
     where  user_id = p_user_id;

    delete  /*+ no_parallel */
      from  account_status_history
     where  user_id = p_user_id;

    delete  /*+ no_parallel */
      from  password_history
     where  user_id = p_user_id;

    delete  /*+ no_parallel */
      from  icam_users
     where  user_id = p_user_id;

  end remove_user;

  procedure reset_password
  (
    p_confirmation_token              confirmation_tokens.confirmation_token%type,
    p_new_password                    varchar2,
    p_client_address                  password_history.client_address%type
  )

  is

    l_user_id                         icam_users.user_id%type;
    l_hashed_username_password        icam_users.hashed_username_password%type;
    l_hashed_new_password             icam_users.hashed_username_password%type;
    l_username                        icam_users.username%type;
    l_random_bytes                    icam_users.random_bytes%type;

  begin

    validate_confirmation_token(p_confirmation_token);

    select  user_id
      into  l_user_id
      from  confirmation_tokens
     where  confirmation_token = p_confirmation_token;

    select  hashed_username_password, username, random_bytes
      into  l_hashed_username_password, l_username, l_random_bytes
      from  icam_users
     where  user_id = l_user_id;

    l_hashed_new_password := hashed_value(l_username||p_new_password, l_random_bytes);

    if l_hashed_username_password = l_hashed_new_password then

      raise_application_error(NEW_OLD_PASSWORDS_MATCH, NEW_OLD_PASSWORDS_MATCH_EMSG);

    end if;

    insert into password_history
      (user_id, old_hashed_username_password, replacement_date, replacement_method, client_address)
      select  user_id, hashed_username_password, systimestamp at time zone 'utc', 'password reset', p_client_address
        from  icam_users
       where  user_id = l_user_id;

    update  icam_users
       set  hashed_username_password = l_hashed_new_password
     where  user_id = l_user_id;

  end reset_password;

  procedure send_change_email_code
  (
    p_user_id                         icam_users.user_id%type,
    p_new_email_address               icam_users.email_address%type,
    p_client_address                  confirmation_tokens.client_address%type
  )

  is

    l_row_exists                      varchar2(1);
    l_change_email_code               varchar2(6) :=
      create_confirmation_token(p_user_id => p_user_id, p_purpose => 'change email',
        p_expiration_date => systimestamp at time zone 'utc' + 1200 / db_twig.SECONDS_PER_DAY,
        p_client_address => p_client_address, p_email_address => p_new_email_address);

  begin

    validate_new_email_address(p_new_email_address);
-- TODO    email.send_change_email_code(p_user_id, p_new_email_address, l_change_email_code);

  end send_change_email_code;

  function site_administrator_check
  (
    p_json_parameters                 json_object_t
  )
  return varchar2

  is

    l_session_id                      icam_sessions.session_id%type := extract_session_id(p_json_parameters);
    l_account_type                    icam_users.account_type%type;

  begin

    select  account_type
      into  l_account_type
      from  icam_users
     where  user_id = get_session_user_id(l_session_id);

    if AT_ADMINISTRATOR = l_account_type then

      return 'true';

    else

      return 'false';

    end if;

  end site_administrator_check;

  procedure site_administrator_check
  (
    p_json_parameters                 json_object_t
  )

  is

    l_true_false                      varchar2(5);

  begin

    l_true_false := site_administrator_check(p_json_parameters);

    if 'false' = l_true_false then

      terminate_session_with_error(extract_session_id(p_json_parameters), NOT_A_SITE_ADMIN, NOT_A_SITE_ADMIN_EMSG);

    end if;

  end site_administrator_check;

  procedure terminate_all_icam_sessions
  (
    p_user_id                         icam_users.user_id%type
  )

  is

  begin

    update  icam_sessions
       set  session_ended = systimestamp at time zone 'utc',
            session_disposition = SD_CANCELED,
            session_status = SS_TERMINATED
     where  user_id = p_user_id;

  end terminate_all_icam_sessions;

  procedure terminate_idle_sessions
  (
    p_terminator_id                   icam_sessions.session_id%type default null
  )

  is

  begin

    update  icam_sessions
       set  session_ended = systimestamp at time zone 'utc',
            session_disposition = SD_TIMEOUT,
            session_status = SS_TERMINATED,
            terminator_id = p_terminator_id
     where  session_status = SS_ACTIVE
       and  client_type = WEBAPP_CLIENT
       and  ( (cast(systimestamp at time zone 'utc' as date) - cast(last_activity as date)) *
              db_twig.SECONDS_PER_DAY) > session_inactivity_limit;

  end terminate_idle_sessions;

  procedure terminate_session_with_error
  (
    p_session_id                      icam_sessions.session_id%type,
    p_error_code                      pls_integer,
    p_error_message                   varchar2
  )

  is

  begin

    update  icam_sessions
       set  session_status = SS_TERMINATED,
            session_ended = systimestamp at time zone 'utc',
            session_disposition = SD_ERROR,
            terminator_id = p_session_id
     where  session_id = p_session_id
       and  session_status = SS_ACTIVE;

    commit;

    raise_application_error(p_error_code, p_error_message);

  end terminate_session_with_error;

  procedure terminate_user_session
  (
    p_session_id                      icam_sessions.session_id%type
  )

  is

  begin

    update  icam_sessions
       set  session_status = SS_TERMINATED,
            session_ended = systimestamp at time zone 'utc',
            session_disposition = SD_LOGOUT,
            terminator_id = p_session_id
     where  session_id = p_session_id;

  end terminate_user_session;

  procedure toggle_account_status
  (
    p_username                        icam_users.username%type
  )

  is

    l_old_status                      icam_users.account_status%type;
    l_new_status                      icam_users.account_status%type;
    l_account_type                    icam_users.account_type%type;
    l_user_id                         icam_users.user_id%type;
    l_rowid                           rowid;

  begin

    select  account_status, account_type, user_id, rowid
      into  l_old_status, l_account_type, l_user_id, l_rowid
      from  icam_users
     where  upper(username) = upper(p_username)
       for  update;

    if AT_ADMINISTRATOR = l_account_type then

      raise_application_error(ACTION_DISALLOWED, ACTION_DISALLOWED_EMSG);

    end if;

    if 'locked' != l_old_status and 'active' != l_old_status then

      raise_application_error(ACTION_DISALLOWED, ACTION_DISALLOWED_EMSG);

    end if;

    if 'locked' = l_old_status then

      l_new_status := AS_ACTIVE;

    else

      l_new_status := AS_LOCKED;

    end if;

    update  icam_users
       set  account_status = l_new_status
     where  rowid = l_rowid;

    insert into account_status_history
      (user_id, prior_status, transition_date, transition_reason)
    values
      (l_user_id, l_old_status, systimestamp at time zone 'utc', 'toggle account status');

  end toggle_account_status;

  procedure update_user_info
  (
    p_user_id                         icam_users.user_id%type,
    p_first_name                      icam_users.first_name%type,
    p_middle_name                     icam_users.middle_name%type,
    p_last_name                       icam_users.last_name%type
  )

  is

  begin

    update  icam_users
       set  first_name = p_first_name,
            middle_name = p_middle_name,
            last_name = p_last_name
     where  user_id = p_user_id;

  end update_user_info;

  procedure update_user_preferences
  (
    p_user_id                         icam_users.user_id%type,
    p_auth_method                     icam_users.auth_method%type,
    p_default_timezone                icam_users.default_timezone%type)

  is

    l_email_address                   icam_users.email_address%type;
--    l_smtp_enabled                    object_vault_profile.smtp_enabled%type;

  begin

/* TODO    select  email_address
      into  l_email_address
      from  icam_users
     where  user_id = p_user_id;

    select  smtp_enabled
      into  l_smtp_enabled
      from  object_vault_profile;

    if 'password' != p_auth_method then

      if OPTION_DISABLED = l_smtp_enabled then

        raise_application_error(FEATURE_DISABLED);

      end if;

      if l_email_address is null then

        raise_application_error(INVALID_EMAIL_ADDRESS);

      end if;

    end if; */

    update  icam_users
       set  auth_method = p_auth_method,
            default_timezone = p_default_timezone
     where  user_id = p_user_id;

  end update_user_preferences;

  procedure update_user_properties
  (
    p_username                        icam_users.username%type,
    p_session_limit                   icam_users.session_limit%type,
    p_session_inactivity_limit        icam_users.session_inactivity_limit%type
  )

  is

  begin

    update  icam_users
       set  session_limit = p_session_limit,
            session_inactivity_limit = p_session_inactivity_limit
     where  upper(username) = upper(p_username);

  end update_user_properties;

  procedure validate_change_email_code
  (
    p_user_id                         icam_users.user_id%type,
    p_change_email_code               confirmation_tokens.confirmation_token%type
  )

  is

  begin

    validate_confirmation_token(p_change_email_code);

    update  icam_users
       set  email_address =
              (select  email_address
                 from  confirmation_tokens
                where  confirmation_token = p_change_email_code)
     where  user_id = p_user_id;

  end validate_change_email_code;

  procedure validate_confirmation_token
  (
    p_confirmation_token              confirmation_tokens.confirmation_token%type,
    p_check_only                      boolean default false
  )

  is

    l_expiration_date                 confirmation_tokens.expiration_date%type;

  begin

    begin

      select  expiration_date
        into  l_expiration_date
        from  confirmation_tokens
       where  confirmation_token = p_confirmation_token
         and  token_status = 'unused'
         and  expiration_date > systimestamp at time zone 'utc';

    exception

    when no_data_found then

      raise_application_error(INVALID_CONFIRMATION_DATA, INVALID_CONFIRMATION_DATA_EMSG);

    end;

    if p_check_only then

      return;

    end if;

    update  confirmation_tokens
       set  disposition_date = systimestamp at time zone 'utc',
            token_status = 'used'
     where  confirmation_token = p_confirmation_token;

  end validate_confirmation_token;

  function validate_login_authorization
  (
    p_confirmation_token              confirmation_tokens.confirmation_token%type
  )
  return clob

  is

    l_user_id                         icam_users.user_id%type;
    l_session_id                      icam_sessions.session_id%type;
    l_client_type                     icam_sessions.client_type%type;
    l_session_limit                   icam_users.session_limit%type;
    l_session_status                  icam_sessions.session_status %type := SS_ACTIVE;
    l_json_object                     json_object_t := json_object_t;
    l_session_inactivity_limit        icam_sessions.session_inactivity_limit%type;

  begin

    validate_confirmation_token(p_confirmation_token);

    select  t.user_id, s.session_id, client_type, session_limit, u.session_inactivity_limit
      into  l_user_id, l_session_id, l_client_type, l_session_limit, l_session_inactivity_limit
      from  confirmation_tokens t, icam_users u, icam_sessions s
     where  confirmation_token = p_confirmation_token
       and  t.session_id = s.session_id
       and  t.user_id = u.user_id;

    if at_session_limit(l_user_id, l_session_limit, l_client_type) and
       not found_timed_out_session(l_user_id, l_client_type, l_session_id) then

      l_session_status := SS_SESSION_LIMIT;

    end if;

    update  icam_sessions
       set  session_status = l_session_status,
            session_inactivity_limit = l_session_inactivity_limit
     where  session_id = l_session_id;

    return icam.get_session_info(l_session_id);

  end validate_login_authorization;

  procedure validate_new_email_address
  (
    p_email_address                   icam_users.email_address%type
  )

  is

    l_valid                           varchar2(1);

  begin

    select  'N'
      into  l_valid
      from  icam_users
     where  upper(email_address) = upper(p_email_address);

    raise_application_error(EMAIL_ADDRESS_EXISTS, EMAIL_ADDRESS_EXISTS_EMSG);

  exception

  when no_data_found then

    null;

  end validate_new_email_address;

  procedure validate_new_username
  (
    p_username                        icam_users.username%type
  )

  is

    l_valid                           varchar2(1);

  begin

    select  'N'
      into  l_valid
      from  icam_users
     where  upper(username) = upper(p_username);

    raise_application_error(USERNAME_TAKEN, USERNAME_TAKEN_EMSG);

  exception

  when no_data_found then

    null;

  end validate_new_username;

  procedure validate_session_id
  (
    p_json_parameters                 json_object_t,
    p_allow_blocked_session           varchar2,
    p_check_header_info               varchar2
  )

  is

    l_session_id                      icam_sessions.session_id%type := extract_session_id(p_json_parameters);
    l_client_address                  icam_sessions.client_address%type default null;
    l_user_agent                      icam_sessions.user_agent%type default null;
    l_last_activity_in_seconds        number(9);
    l_session_inactivity_limit        icam_sessions.session_inactivity_limit%type;
    l_session_address                 icam_sessions.client_address%type;
    l_session_user_agent              icam_sessions.user_agent%type;
    l_session_status                  icam_sessions.session_status%type;
    l_client_type                     icam_sessions.client_type%type;

  begin

    begin

      l_client_address := p_json_parameters.get_string('clientAddress');
      l_user_agent := p_json_parameters.get_string('userAgent');

      select  ( cast(systimestamp at time zone 'utc' as date) - cast(last_activity as date)) * db_twig.SECONDS_PER_DAY,
              s.session_inactivity_limit, client_address, user_agent, session_status, client_type
        into  l_last_activity_in_seconds, l_session_inactivity_limit, l_session_address, l_session_user_agent, l_session_status,
              l_client_type
        from  icam_sessions s, icam_users u
       where  session_id = l_session_id
         and  s.user_id = u.user_id;

      if l_last_activity_in_seconds > l_session_inactivity_limit and -1 != l_session_inactivity_limit then

        terminate_session_with_error(l_session_id, SESSION_TIMEOUT, SESSION_TIMEOUT_EMSG);

      end if;

      if (SS_CHANGE_PASSWORD = l_session_status or
          SS_SESSION_LIMIT = l_session_status or
          SS_AUTH_CODE = l_session_status ) and 'N' = p_allow_blocked_session then

        terminate_session_with_error(l_session_id, INVALID_SESSION_STATUS, INVALID_SESSION_STATUS_EMSG);

      end if;

      if SS_TERMINATED = l_session_status then

        raise_application_error(INVALID_SESSION_STATUS, INVALID_SESSION_STATUS_EMSG);

      end if;

--      if l_client_address is not null and l_user_agent is not null and restapi.API_CLIENT != l_client_type then
      if 'Y' = p_check_header_info and API_CLIENT != l_client_type then

        check_header_info(l_session_id, l_session_address, l_client_address, l_session_user_agent, l_user_agent);

      end if;

    exception

    when no_data_found then

      raise_application_error(INVALID_SESSION_ID, INVALID_SESSION_ID_EMSG);

    end;

    if AS_ACTIVE = l_session_status then                           -- This requires PRAGMA AUTONOMOUS_TRANSACTION

      update_last_activity(l_session_id);

    end if;

  end validate_session_id;

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  )

  is

    l_json_object                     json_object_t := json_object_t(p_json_parameters);
    l_session_id                      icam_sessions.session_id%type := extract_session_id(l_json_object);

  begin

    if 'none' = p_required_authorization_level then

      return;

    end if;

    validate_session_id(p_json_parameters, p_allow_blocked_session, 'Y');

    if 'administrator' = p_required_authorization_level then

      site_administrator_check(p_json_parameters);

    end if;

  end validate_session;

  procedure validate_session
  (
    p_entry_point                     middle_tier_map.entry_point%type,
    p_json_parameters                 json_object_t
  )

  is

    l_required_authorization_level    middle_tier_map.required_authorization_level%type;
    l_allow_blocked_session           middle_tier_map.allow_blocked_session%type;

  begin

    select  required_authorization_level, allow_blocked_session
      into  l_required_authorization_level, l_allow_blocked_session
      from  middle_tier_map
     where  entry_point = p_entry_point;

    validate_session(p_json_parameters, l_required_authorization_level, l_allow_blocked_session);

  end validate_session;

end icam;
/
show errors package body icam
