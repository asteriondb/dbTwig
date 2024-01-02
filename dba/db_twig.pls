create or replace
package body db_twig as

  s_json_response                     constant varchar2(23) := '{"response": "success"}';

  s_user_error_max                    constant pls_integer := -20000;
  s_user_error_min                    constant pls_integer := -20999;

  PLSQL_COMPILER_ERROR                EXCEPTION;
  pragma exception_init(PLSQL_COMPILER_ERROR, -6550);

  PACKAGE_INVALIDATED                 EXCEPTION;
  pragma exception_init(PACKAGE_INVALIDATED, -4061);

  PACKAGE_DISCARDED                   EXCEPTION;
  pragma exception_init(PACKAGE_DISCARDED, -4068);

  procedure db_twig_error
  (
    p_error_code                      db_twig_errors.error_code%type,
    p_json_parameters                 db_twig_errors.json_parameters%type default null,
    p_error_message                   db_twig_errors.error_message%type default null
  )

  is

    PRAGMA AUTONOMOUS_TRANSACTION;

  begin

    insert into db_twig_errors
      (error_code, json_parameters, error_message)
    values
      (p_error_code, p_json_parameters, p_error_message);

    commit;

  end db_twig_error;

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

  function call_rest_api
  (
    p_json_parameters                 clob
  )
  return clob

  is

    l_json_parameters                 json_object_t := json_object_t(p_json_parameters);
    l_plsql_text                      varchar2(1024);
    l_object_type                     varchar2(9);
    l_object_name                     varchar2(128);
    l_json_string                     clob;
    l_json_data                       json_object_t;
    l_entry_point                     varchar2(128) := l_json_parameters.get_string('entryPoint');
    l_service_name                    db_twig_services.service_name%type := l_json_parameters.get_string('serviceName');
    l_service_owner                   db_twig_services.service_owner%type;
    l_complete_object_name            varchar2(257);
    l_replace_error_stack             db_twig_services.replace_error_stack%type;
    l_session_validation_procedure    db_twig_services.session_validation_procedure%type;
    l_api_error_handler               db_twig_services.api_error_handler%type;
    l_error_text                      clob;
    l_error_code                      pls_integer;
    l_object_group                    varchar2(128);

  begin

    begin

      select  service_owner, replace_error_stack, session_validation_procedure, api_error_handler
        into  l_service_owner, l_replace_error_stack, l_session_validation_procedure, l_api_error_handler
        from  db_twig_services
       where  service_name = l_service_name;

    exception when no_data_found then

      db_twig_error(sqlcode, p_json_parameters, sqlerrm);
      raise_application_error(-20100, 'Invalid service name', false);

    end;

    l_plsql_text :=
      'select  object_type, object_name, object_group ' ||
      '  from  '||l_service_owner||'.middle_tier_map ' ||
      ' where  entry_point = :entryPoint';

    begin

      execute immediate l_plsql_text
        into l_object_type, l_object_name, l_object_group
        using l_entry_point;

    exception when no_data_found then

      db_twig_error(sqlcode, p_json_parameters, sqlerrm);
      raise_application_error(-20100, 'Invalid entry point', false);

    end;

    execute immediate 'begin '||l_service_owner||'.'||l_session_validation_procedure||'(:entry_point, json_object_t(:p_json_parameters)); end;'
      using l_entry_point, p_json_parameters;

    l_complete_object_name := l_service_owner||'.'||l_object_name;

    begin

      if 'function' = l_object_type then

        l_plsql_text := 'begin :l_json_string := '||l_complete_object_name||'(json_object_t(:p_json_parameters)); end;';
        execute immediate l_plsql_text using out l_json_string, p_json_parameters;

      else

        l_plsql_text := 'begin '||l_complete_object_name||'(json_object_t(:p_json_parameters)); end;';
        execute immediate l_plsql_text using p_json_parameters;
        l_json_string := s_json_response;

      end if;

    exception

    when PLSQL_COMPILER_ERROR then

      raise_application_error(-20100, l_plsql_text, true);

    when PACKAGE_INVALIDATED or PACKAGE_DISCARDED then

      raise;

    when others then

      l_json_data := restapi_error(l_service_owner, l_api_error_handler, p_json_parameters, l_service_name, l_object_group);

      if l_json_data.get_string('errorId') is not null then

        l_error_text := 'Please reference error ID '||l_json_data.get_string('errorId')||' when contacting support.'||chr(10);

      end if;

      l_error_code := sqlcode;
      if s_user_error_min > l_error_code or s_user_error_max < l_error_code then

        l_error_code := -20100;

      end if;

      if 'Y' = l_replace_error_stack then

        l_error_text := l_error_text||'ORA-'||utl_call_stack.error_number(1)||': '||utl_call_stack.error_msg(1);
        raise_application_error(l_error_code, l_error_text, false);

      else

        l_error_text := utl_call_stack.error_msg(1)||chr(10)||l_error_text;
        raise_application_error(l_error_code, l_error_text, true);

      end if;

    end;

    return l_json_string;

  end call_rest_api;

end db_twig;
/
show errors package body db_twig
