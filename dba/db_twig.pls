create or replace
package body db_twig as

  s_json_response                     constant varchar2(23) := '{"response": "success"}';

  s_user_error_max                    constant pls_integer := -20000;
  s_user_error_min                    constant pls_integer := -20999;

  PLSQL_COMPILER_ERROR                EXCEPTION;
  pragma exception_init(PLSQL_COMPILER_ERROR, -6550);

  procedure rest_api_error
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

  end rest_api_error;

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
    l_json_data                       clob;
    l_entry_point                     varchar2(128) := l_json_parameters.get_string('entryPoint');
    l_service_name                    db_twig_services.service_name%type := l_json_parameters.get_string('serviceName');
    l_service_owner                   db_twig_services.service_owner%type;
    l_complete_object_name            varchar2(257);
    l_replace_error_stack             db_twig_services.replace_error_stack%type;
    l_session_validation_procedure    db_twig_services.session_validation_procedure%type;

  begin

    begin

      select  service_owner, replace_error_stack, session_validation_procedure
        into  l_service_owner, l_replace_error_stack, l_session_validation_procedure
        from  db_twig_services
       where  service_name = l_service_name;

    exception when no_data_found then

      rest_api_error(sqlcode, p_json_parameters, sqlerrm);
      raise_application_error(-20100, 'Invalid service name parameter value.', false);

    end;

    l_plsql_text :=
      'select  object_type, object_name ' ||
      '  from  '||l_service_owner||'.middle_tier_map ' ||
      ' where  entry_point = :entryPoint';

    begin

      execute immediate l_plsql_text
        into l_object_type, l_object_name
        using l_entry_point;

    exception when no_data_found then

      rest_api_error(sqlcode, p_json_parameters, sqlerrm);
      raise_application_error(-20100, 'Invalid entry point parameter value.', false);

    end;

    execute immediate 'begin '||l_service_owner||'.'||l_session_validation_procedure||'(:l_object_type, :l_object_name, :l_json_parameters); end;'
      using l_object_type, l_object_name, p_json_parameters;

    l_complete_object_name := l_service_owner||'.'||l_object_name;

    begin

      if 'function' = l_object_type then

        l_plsql_text := 'begin :l_json_data := '||l_complete_object_name||'(:l_json_parameters); end;';
        execute immediate l_plsql_text using out l_json_data, p_json_parameters;

      else

        l_plsql_text := 'begin '||l_complete_object_name||'(:l_json_parameters); end;';

        execute immediate l_plsql_text using p_json_parameters;

        l_json_data := s_json_response;

      end if;

    exception

    when PLSQL_COMPILER_ERROR then

      raise_application_error(-20100, l_plsql_text, true);

    when others then

      if 'Y' = l_replace_error_stack and sqlcode <= s_user_error_max and sqlcode >= s_user_error_min then

        raise_application_error(sqlcode, '//'||substr(sqlerrm, instr(sqlerrm, ':')+2)||'\\', false);

      else

        raise;

      end if;

    end;

    return l_json_data;

  end call_rest_api;

end db_twig;
/
show errors package body db_twig
