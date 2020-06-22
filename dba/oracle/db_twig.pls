create or replace
package body db_twig as

  function call_rest_api
  (
    p_json_parameters                 clob
  )
  return clob

  is

    l_json_parameters                 json_object_t := json_object_t(p_json_parameters);
    l_json_object                     json_object_t;
    l_plsql_text                      varchar2(1024);
    l_object_type                     middle_tier_map.object_type%type;
    l_object_name                     middle_tier_map.object_name%type;
    l_json_data                       clob;
    l_entry_point                     middle_tier_map.entry_point%type := l_json_parameters.get_string('entryPoint');
    l_object_owner                    user_users.username%type := l_json_parameters.get_string('databaseUsername');
    l_fully_qualified_object          varchar2(257);

  begin

    select  object_type, object_name
      into  l_object_type, l_object_name
      from  middle_tier_map
     where  entry_point = l_entry_point;

    if l_object_owner is null then

      l_fully_qualified_object := l_object_name;

    else

      l_fully_qualified_object := l_object_owner||'.'||l_object_name;

    end if;

    if 'function' = l_object_type then

      l_plsql_text := 'begin :l_json_data := '||l_fully_qualified_object||'(:l_json_parameters); end;';
      execute immediate l_plsql_text using out l_json_data, p_json_parameters;

    else

      l_plsql_text := 'begin '||l_fully_qualified_object||'(:l_json_parameters); end;';
      execute immediate l_plsql_text using p_json_parameters;

      l_json_object := json_object_t;
      l_json_object.put('response', 'success');
      l_json_data := l_json_object.to_string;

    end if;

    return l_json_data;

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
