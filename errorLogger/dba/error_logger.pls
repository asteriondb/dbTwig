create or replace
package body error_logger as

  SERVICE_NAME                        constant varchar2(4) := 'elog';

  function get_api_error_log
  (
    p_service_id                      api_errors.service_id%type
  )
  return clob

  is

    l_result                          clob;
    l_rows                            pls_integer;

  begin

    select  count(*), json_object('apiErrorLog' is
            json_arrayagg(json_object(
              'errorTimestamp' is db_twig.convert_timestamp_to_unix_timestamp(error_timestamp),
              'errorId' is error_id,
              'username' is icam.get_session_username(session_id),
              'errorCode' is error_code,
              'errorMessage' is error_message,
              'jsonParameters' is json_parameters format json returning clob)
              order by db_twig.convert_timestamp_to_unix_timestamp(error_timestamp) desc returning clob) returning clob)
      into  l_rows, l_result
      from  api_errors e
     where service_id = p_service_id;

    if 0 = l_rows then

      return db_twig.empty_json_array('apiErrorLog');

    end if;

    return l_result;

  end get_api_error_log;

  function get_error_stack return clob

  is

    l_error_text                      clob;

  begin

    for x in 0..utl_call_stack.error_depth - 1 loop

      l_error_text := l_error_text||utl_call_stack.error_msg(x+1)||chr(10);

    end loop;

    return l_error_text;

  end get_error_stack;

  function log_api_error
  (
    p_json_parameters                 api_errors.json_parameters%type,
    p_service_id                      api_errors.service_id%type
  )
  return api_errors.error_id%type

  is

    PRAGMA AUTONOMOUS_TRANSACTION;

    l_json_parameters                 json_object_t := json_object_t(p_json_parameters);
    l_session_id                      api_errors.session_id%type := l_json_parameters.get_string('sessionId');
    l_error_id                        api_errors.error_id%type :=
      dbms_random.string('x', get_column_length('API_ERRORS', 'ERROR_ID') - 1);
    l_error_text                      clob;
    l_error_number                    pls_integer := utl_call_stack.error_number(1);
    l_clob                            clob;

  begin

    l_error_id := substr(l_error_id, 1, 5) || '-' || substr(l_error_id, 6);

    l_error_text := 'ORA-'||l_error_number||': '||get_error_stack;

    if l_json_parameters.has('password') then

      l_json_parameters.remove('password');

    end if;

    l_clob := l_json_parameters.to_clob;

    insert into api_errors
      (error_id, error_code, error_message, session_id, json_parameters, service_id)
    values
      (l_error_id, l_error_number, l_error_text, l_session_id, l_clob, p_service_id);

    commit;

    return l_error_id;

  end log_api_error;


  procedure purge_api_errors
  (
    p_service_id                      api_errors.service_id%type
  )

  is

    l_dml_text                        varchar2(128);

  begin

    delete  from  api_errors
     where  service_id = p_service_id;

  end purge_api_errors;

  function restapi_error
  (
    p_json_parameters                 api_errors.json_parameters%type,
    p_service_id                      api_errors.service_id%type
  )
  return json_object_t

  is

    l_error_id                        api_errors.error_id%type;
    l_json_object                     json_object_t := json_object_t;

  begin

    l_error_id := error_logger.log_api_error(p_json_parameters, p_service_id);
    l_json_object.put('errorId', l_error_id);

    return l_json_object;

  end restapi_error;

end error_logger;
/
show errors package body error_logger
