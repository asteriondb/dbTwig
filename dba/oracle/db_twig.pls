create or replace
package body db_twig as

  s_json_response                     constant varchar2(23) := '{"response": "success"}';

  PLSQL_COMPILER_ERROR                EXCEPTION;
  pragma exception_init(PLSQL_COMPILER_ERROR, -6550);

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

  begin

    select  service_owner
      into  l_service_owner
      from  db_twig_services
     where  service_name = l_service_name;

    execute immediate
      'select  object_type, object_name ' ||
      '  from  '||l_service_owner||'.middle_tier_map ' ||
      ' where  entry_point = :entryPoint'
      into l_object_type, l_object_name
      using l_entry_point;

    l_complete_object_name := l_service_owner||'.'||l_object_name;

    if 'function' = l_object_type then

      l_plsql_text := 'begin :l_json_data := '||l_complete_object_name||'(:l_json_parameters); end;';
      execute immediate l_plsql_text using out l_json_data, p_json_parameters;

    else

      l_plsql_text := 'begin '||l_complete_object_name||'(:l_json_parameters); end;';

      execute immediate l_plsql_text using p_json_parameters;

      l_json_data := s_json_response;

    end if;

    return l_json_data;

  exception

  when PLSQL_COMPILER_ERROR then

    raise_application_error(-20100, l_plsql_text);

  end call_rest_api;

  function rest_api_error
  (
    p_json_parameters                 clob
  )
  return clob

  is

    l_json_parameters                 json_object_t := json_object_t(p_json_parameters);
    l_json_data                       clob;

  begin

    l_json_parameters.put('entryPoint', 'restApiError');
    l_json_data := call_rest_api(l_json_parameters.to_string);

    return l_json_data;

  end rest_api_error;

end db_twig;
/
show errors package body db_twig
