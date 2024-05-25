create or replace
package body db_twig as

  s_user_error_max                    constant pls_integer := -20000;
  s_user_error_min                    constant pls_integer := -20999;

  PLSQL_COMPILER_ERROR                EXCEPTION;
  pragma exception_init(PLSQL_COMPILER_ERROR, -6550);

  PACKAGE_INVALIDATED                 EXCEPTION;
  pragma exception_init(PACKAGE_INVALIDATED, -4061);

  PACKAGE_DISCARDED                   EXCEPTION;
  pragma exception_init(PACKAGE_DISCARDED, -4068);

  INVALID_PARAMETERS_EC               constant pls_integer := -20138;

  INVALID_PARAMETERS                  EXCEPTION;
  pragma exception_init(INVALID_PARAMETERS, INVALID_PARAMETERS_EC);             -- Borrowed from AsterionDB.
  INVALID_PARAMETERS_MSG              constant varchar2(19) := 'Invalid parameters.';

  procedure db_twig_error
  (
    p_error_code                      db_twig_errors.error_code%type,
    p_json_parameters                 db_twig_errors.json_parameters%type default null,
    p_error_message                   db_twig_errors.error_message%type default null
  )

  is

    PRAGMA AUTONOMOUS_TRANSACTION;

    l_json_parameters                 json_object_t := json_object_t(p_json_parameters);
    l_clob                            clob;

  begin

    if l_json_parameters.has('password') then

      l_json_parameters.remove('password');

    end if;

    l_clob := l_json_parameters.to_clob;

    insert into db_twig_errors
      (error_code, json_parameters, error_message)
    values
      (p_error_code, l_clob, p_error_message);

    commit;

  end db_twig_error;

  function empty_json_array
  (
    p_key                             varchar2
  )
  return clob

  is

    l_json_object                     json_object_t := json_object_t;

  begin

    l_json_object.put(p_key, json_array_t);
    return l_json_object.to_clob;

  end empty_json_array;

  function get_array_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required_parameter              boolean default true,
    p_default_value                   json_array_t default null
  )
  return json_array_t

  is

  begin

    if p_json_parameters.has(p_key) then

      return treat(p_json_parameters.get(p_key) as json_array_t);

    else

      if p_required_parameter then

        raise_application_error(INVALID_PARAMETERS_EC, INVALID_PARAMETERS_MSG, false);

      else

        return p_default_value;

      end if;

    end if;

  end get_array_parameter;

  function get_clob_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required_parameter              boolean default true,
    p_default_value                   clob default null
  )
  return clob

  is

  begin

    if p_json_parameters.has(p_key) then

      return p_json_parameters.get_clob(p_key);

    else

      if p_required_parameter then

        raise_application_error(INVALID_PARAMETERS_EC, INVALID_PARAMETERS_MSG);

      else

        return p_default_value;

      end if;

    end if;

  end get_clob_parameter;

  function get_number_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required_parameter              boolean default true,
    p_default_value                   number default null
  )
  return number

  is

  begin

    if p_json_parameters.has(p_key) then

      return p_json_parameters.get_number(p_key);

    else

      if p_required_parameter then

        raise_application_error(INVALID_PARAMETERS_EC, INVALID_PARAMETERS_MSG);

      else

        return p_default_value;

      end if;

    end if;

  end get_number_parameter;

  function get_object_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required_parameter              boolean default true,
    p_default_value                   json_object_t default null
  )
  return json_object_t

  is

  begin

    if p_json_parameters.has(p_key) then

      return p_json_parameters.get_object(p_key);

    else

      if p_required_parameter then

        raise_application_error(INVALID_PARAMETERS_EC, INVALID_PARAMETERS_MSG);

      else

        return p_default_value;

      end if;

    end if;

  end get_object_parameter;

  function get_string_parameter
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required_parameter              boolean default true,
    p_default_value                   varchar2 default null
  )
  return varchar2

  is

  begin

    if p_json_parameters.has(p_key) then

      return p_json_parameters.get_string(p_key);

    else

      if p_required_parameter then

        raise_application_error(INVALID_PARAMETERS_EC, INVALID_PARAMETERS_MSG);

      else

        return p_default_value;

      end if;

    end if;

  end get_string_parameter;

  function restapi_error
  (
    p_service_owner                   db_twig_services.service_owner%type,
    p_api_error_handler               db_twig_services.api_error_handler%type,
    p_json_parameters                 db_twig_errors.json_parameters%type,
    p_service_name                    varchar2,
    p_object_group                    varchar2
  )
  return json_object_t

  is

    l_sql_text                        clob;
    l_json_object                     json_object_t;

  begin

    l_sql_text := 'begin :result := '||p_service_owner||'.'||p_api_error_handler||'(:jsonParameters, :serviceName, :objectGroup); end;';
    execute immediate l_sql_text using out l_json_object, p_json_parameters, p_service_name, p_object_group;

    return l_json_object;

  end restapi_error;

---
---
---

  function call_restapi
  (
    p_json_parameters                 clob
  )
  return clob

  is

    l_json_parameters                 json_object_t;
    l_plsql_text                      varchar2(1024);
    l_object_type                     varchar2(9);
    l_object_name                     varchar2(128);
    l_json_response                   clob := '{"status": "success"}';
    l_json_data                       json_object_t;
    l_entry_point                     varchar2(128);
    l_service_name                    db_twig_services.service_name%type;
    l_service_owner                   db_twig_services.service_owner%type;
    l_complete_object_name            varchar2(257);
    l_production_mode                 db_twig_services.production_mode%type;
    l_session_validation_procedure    db_twig_services.session_validation_procedure%type;
    l_api_error_handler               db_twig_services.api_error_handler%type;
    l_error_text                      clob;
    l_error_code                      pls_integer;
    l_object_group                    varchar2(128);
    l_log_all_requests                db_twig_services.log_all_requests%type;

  begin

    select  production_mode
      into  l_production_mode
      from  dbtwig_profile;

    if p_json_parameters is null then

      db_twig_error(INVALID_PARAMETERS_EC, null, 'No parameters specified.');

      if 'Y' = l_production_mode then

        raise_application_error(GENERIC_ERROR, 'No information available', false);

      else

        raise_application_error(INVALID_PARAMETERS_EC, 'Null Parameter String', false);

      end if;

    end if;

    l_json_parameters := json_object_t(p_json_parameters);

    begin

      l_service_name  := get_string_parameter(l_json_parameters, 'serviceName');
      l_entry_point := get_string_parameter(l_json_parameters, 'entryPoint');

    exception

    when others then

      db_twig_error(INVALID_PARAMETERS_EC, p_json_parameters, sqlerrm);
      if 'Y' = l_production_mode then

        raise_application_error(GENERIC_ERROR, 'No information available', false);

      else

        raise;

      end if;

    end;

    begin

      select  service_owner, production_mode, session_validation_procedure, api_error_handler, log_all_requests
        into  l_service_owner, l_production_mode, l_session_validation_procedure, l_api_error_handler,
              l_log_all_requests
        from  db_twig_services
       where  service_name = l_service_name;

    exception when no_data_found then

      db_twig_error(INVALID_PARAMETERS_EC, p_json_parameters, 'Invalid service name.');
      if 'Y' = l_production_mode then

        raise_application_error(GENERIC_ERROR, 'No information available', false);

      else

        raise_application_error(INVALID_PARAMETERS_EC, 'Invalid service name.', false);

      end if;

    end;

    if 'Y' = l_log_all_requests then

      if l_json_parameters.has('password') then

        l_json_parameters.remove('password');

      end if;

      insert into logged_requests
        (request)
      values
        (l_json_parameters.to_clob);

      commit;

    end if;

    l_plsql_text :=
      'select  object_type, object_name, object_group ' ||
      '  from  '||l_service_owner||'.middle_tier_map ' ||
      ' where  entry_point = :entryPoint';

    begin

      execute immediate l_plsql_text
        into l_object_type, l_object_name, l_object_group
        using l_entry_point;

    exception when no_data_found then

      db_twig_error(GENERIC_ERROR, p_json_parameters, 'Invalid entry point.');
      if 'Y' = l_production_mode then

        raise_application_error(GENERIC_ERROR, 'No information available', false);

      else

        raise_application_error(INVALID_PARAMETERS_EC, 'Invalid entry point.', false);

      end if;

    end;

    l_complete_object_name := l_service_owner||'.'||l_object_name;

    begin

      execute immediate 'begin '||l_service_owner||'.'||l_session_validation_procedure||'(:entry_point, json_object_t(:p_json_parameters)); end;'
        using l_entry_point, p_json_parameters;

      if 'function' = l_object_type then

        l_plsql_text := 'begin :l_json_response := '||l_complete_object_name||'(json_object_t(:p_json_parameters)); end;';
        execute immediate l_plsql_text using out l_json_response, p_json_parameters;

      else

        l_plsql_text := 'begin '||l_complete_object_name||'(json_object_t(:p_json_parameters)); end;';
        execute immediate l_plsql_text using p_json_parameters;

      end if;

    exception

    when PLSQL_COMPILER_ERROR then

      raise_application_error(GENERIC_ERROR, l_plsql_text, true);

    when PACKAGE_INVALIDATED or PACKAGE_DISCARDED then

      raise;

    when others then

      l_json_data := restapi_error(l_service_owner, l_api_error_handler, p_json_parameters, l_service_name, l_object_group);

      if l_json_data.get_string('errorId') is not null then

        l_error_text := 'Please reference error ID '||l_json_data.get_string('errorId')||' when contacting support.'||chr(10);

      end if;

      l_error_code := sqlcode;
      if s_user_error_min > l_error_code or s_user_error_max < l_error_code then

        l_error_code := GENERIC_ERROR;

      end if;

      if 'Y' = l_production_mode then

        l_error_text := l_error_text||'ORA-'||utl_call_stack.error_number(1)||': '||utl_call_stack.error_msg(1);
        raise_application_error(l_error_code, l_error_text, false);

      else

        l_error_text := utl_call_stack.error_msg(1)||chr(10)||l_error_text;
        raise_application_error(l_error_code, l_error_text, true);

      end if;

    end;

    return l_json_response;

  end call_restapi;

  function convert_date_to_unix_timestamp
  (
    p_date_value                      date
  )
  return number

  is

  begin

    if p_date_value is null then

      return null;

    end if;

    return trunc(p_date_value - to_date('01-Jan-1970')) * db_twig.SECONDS_PER_DAY;

  end convert_date_to_unix_timestamp;

  function convert_timestamp_to_unix_timestamp
  (
    p_timestamp_value                 timestamp
  )
  return varchar2

  is

  begin

    if p_timestamp_value is null then

      return null;

    end if;

    return to_char((trunc(cast(p_timestamp_value as date) - to_date('01-Jan-1970')) * db_twig.SECONDS_PER_DAY) +
      to_char(p_timestamp_value, 'sssss')) ||
      '.' || to_char(p_timestamp_value, 'FF6');

  end convert_timestamp_to_unix_timestamp;

  procedure convert_timestamp_to_timeval
  (
    p_timestamp_value                 timestamp,
    p_tv_sec                          out number,
    p_tv_usec                         out number
  )

  is

  begin

    p_tv_sec := (trunc(cast(p_timestamp_value as date) - to_date('01-Jan-1970')) * db_twig.SECONDS_PER_DAY) +
      to_char(p_timestamp_value, 'sssss');
    p_tv_usec := to_char(p_timestamp_value, 'FF6');

  end convert_timestamp_to_timeval;

  function convert_unix_timestamp_to_date
  (
    p_unix_timestamp                  number
  )
  return date

  is

  begin

    return to_date('01-jan-1970') + (p_unix_timestamp / db_twig.SECONDS_PER_DAY);

  end convert_unix_timestamp_to_date;

  function convert_unix_timestamp_to_timestamp
  (
    p_unix_timestamp                  float
  )
  return timestamp

  is

    l_timestamp                       timestamp;
    l_nanoseconds                     float := mod(p_unix_timestamp, 1);

  begin

    l_timestamp := to_timestamp('01-jan-1970') + (p_unix_timestamp / db_twig.SECONDS_PER_DAY);
    l_timestamp := l_timestamp + numtodsinterval(l_nanoseconds, 'second');
    return l_timestamp;

  end convert_unix_timestamp_to_timestamp;

  function get_dbtwig_errors return clob

  is

    l_clob                            clob;
    l_rows                            pls_integer;

  begin

    select  json_object('dbTwigErrors'  is json_arrayagg(json_object(
              'errorTimestamp'          is db_twig.convert_timestamp_to_unix_timestamp(error_timestamp),
              'errorCode'               is error_code,
              'jsonParameters'          is json_parameters format json,
              'errorMessage'            is error_message returning clob)
              order by db_twig.convert_timestamp_to_unix_timestamp(error_timestamp) desc returning clob) returning clob),
            count(*)
      into  l_clob, l_rows
      from  db_twig_errors;

    if l_rows = 0 then

      return empty_json_array('dbTwigErrors');

    end if;

    return l_clob;

  end get_dbtwig_errors;

end db_twig;
/
show errors package body db_twig
