create or replace
package body dbplugin_api as

/*

Copyright 2014 - 2025 by AsterionDB, Inc. All rights reserved.

*/

-- These values are derrived from pluginDefs.h...  Note that 5 and 10 are used
-- for shutdown purposes and are declared in the package definition.

  COMPONENT_NAME                      CONSTANT varchar2(8) := 'dbPlugin';

  CONNECT_TO_PLUGIN_MSG               CONSTANT pls_integer := 15;
  DEBUG_PLUGIN_MSG                    CONSTANT pls_integer := 20;
  CALL_PLUGIN_MSG                     CONSTANT pls_integer := 40;
  DISCONNECT_FROM_PLUGIN_MSG          CONSTANT pls_integer := 90;
  TERMINATE_DEBUG_MSG                 CONSTANT pls_integer := 120;

  PYTHON_PLUGIN                       CONSTANT varchar2(18) := 'pythonScriptRunner';

  DEBUG_TIMEOUT                       CONSTANT pls_integer := 60;

  SUCCESS                             CONSTANT pls_integer := 0;

  MAX_PAYLOAD_SIZE                    CONSTANT pls_integer := 4000;

  PLUGIN_SERVER_ERROR                 constant pls_integer := -20001;
  PLUGIN_SERVER_ERROR_EMSG            constant varchar2(32) := 'DbPluginServer returned an error';

  s_call_timeout                      pls_integer := dbplugin_api.DEFAULT_TIMEOUT;
  s_plugin_server_queue_name          varchar2(256) := sys_context('USERENV', 'CURRENT_SCHEMA')||'.'||dbplugin_api.SERVER_QUEUE;
  s_client_handle                     varchar2(24) := dbms_session.unique_session_id;

  dequeue_timeout exception;
  pragma exception_init(dequeue_timeout, -25228);

  invalid_json exception;
  pragma exception_init(invalid_json, -40834);

  function get_msg_for_plugin_client return json_object_t

  is

    l_rc                              pls_integer;
    l_dequeue_options                 DBMS_AQ.dequeue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);
    l_payload                         plugin$message_t;
    l_json_response                   json_object_t;
    l_plugin_response                 json_object_t;

  begin

    l_dequeue_options.wait := s_call_timeout;
    l_dequeue_options.navigation := DBMS_AQ.FIRST_MESSAGE;
    l_dequeue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_dequeue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_dequeue_options.deq_condition := 'tab.user_data.client_handle = '''||s_client_handle||'''';

    dbms_aq.dequeue(queue_name => s_plugin_server_queue_name, dequeue_options => l_dequeue_options,
      message_properties => l_message_properties, payload => l_payload, msgid => l_message_handle);

    l_json_response := json_object_t(l_payload.message_payload);

    if SUCCESS != l_json_response.get_number('exceptionValue') then

      l_plugin_response := l_json_response.get_object('pluginResponse');
      raise_application_error(PLUGIN_SERVER_ERROR, PLUGIN_SERVER_ERROR||' - '||l_plugin_response.get_string('errorMessage'));

    end if;

    return l_json_response.get_object('pluginResponse');

  end get_msg_for_plugin_client;

  procedure send_msg_to_plugin_server
  (
    p_plugin_server                   plugin_servers.plugin_server%type,
    p_message_payload                 json_object_t
  )
  as

    l_enqueue_options                 DBMS_AQ.enqueue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);
    l_message_payload                 json_object_t := p_message_payload;
    l_payload                         plugin$message_t;

  begin

    if MAX_PAYLOAD_SIZE < dbms_lob.getlength(p_message_payload.to_clob) then

      raise_application_error(PLUGIN_SERVER_ERROR, 'Payload message size overflow.');

    end if;

    l_message_properties.expiration := MESSAGE_EXPIRATION;
    l_enqueue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_enqueue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_message_properties.delay := DBMS_AQ.NO_DELAY;
--    l_message_properties.correlation := p_plugin_server;

    l_message_payload.put('clientHandle', s_client_handle);
    l_payload := plugin$message_t(null, p_plugin_server, l_message_payload.to_clob);

    dbms_aq.enqueue(queue_name => s_plugin_server_queue_name, enqueue_options => l_enqueue_options,
      message_properties => l_message_properties, payload => l_payload, msgid => l_message_handle);

  end send_msg_to_plugin_server;

---
--- Public functions and procedures....
---

  function call_plugin
  (
    p_plugin_process                  json_object_t,
    p_function                        varchar2,
    p_json_parameters                 json_object_t default null,
    p_timeout_value                   pls_integer default null
  )
  return json_object_t

  is

    l_payload                         json_object_t := json_object_t;

  begin

    l_payload.put('messageType', dbplugin_api.CALL_PLUGIN_MSG);
    l_payload.put('pluginProcessId', p_plugin_process.get_number('pluginProcessId'));
    l_payload.put('function', p_function);
    l_payload.put('parameters', p_json_parameters);

    if p_timeout_value is not null then

      s_call_timeout := p_timeout_value;

    end if;

    send_msg_to_plugin_server(p_plugin_process.get_string('pluginServer'), l_payload);
    return get_msg_for_plugin_client;

  exception when others then

    error_logger.log_api_error(p_plugin_process.to_clob, db_twig.get_service_id(p_plugin_process.get_string('serviceName')));
    raise;

  end call_plugin;

  function connect_to_plugin_server
  (
    p_plugin_module                   plugin_modules.plugin_module%type,
    p_service_name                    varchar2,
    p_debug_plugin                    boolean default false
  )
  return json_object_t

  is

    l_message_payload                 json_object_t := json_object_t;
    l_plugin_server                   plugin_servers.plugin_server%type;
    l_json_response                   json_object_t;

  begin

    if true = p_debug_plugin then

      l_message_payload.put('messageType', dbplugin_api.DEBUG_PLUGIN_MSG);
      s_call_timeout := DEBUG_TIMEOUT;

    else

      l_message_payload.put('messageType', dbplugin_api.CONNECT_TO_PLUGIN_MSG);

    end if;

    l_message_payload.put('pluginModule', p_plugin_module);

    for server_row in
    (
      select  m.plugin_server
        from  plugin_modules m, plugin_servers s
       where  m.plugin_module = p_plugin_module
        and   m.plugin_server = s.plugin_server
       order  by s.last_activity_timestamp asc
    )
    loop

      l_plugin_server := server_row.plugin_server;
      exit;

    end loop;

    if l_plugin_server is null then

      raise_application_error(PLUGIN_SERVER_ERROR, 'Requested plugin is not available: ' || p_plugin_module);

    end if;

    send_msg_to_plugin_server(l_plugin_server, l_message_payload);
    l_json_response := get_msg_for_plugin_client;
    l_json_response.put('serviceName', p_service_name);
    return l_json_response;

  end connect_to_plugin_server;

  function connect_to_plugin_server
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_debug_plugin                    boolean := false;

  begin

    if p_json_parameters.get_string('debugPlugin') = 'true' then

      l_debug_plugin := true;

    end if;

    return connect_to_plugin_server(p_json_parameters.get_string('pluginModule'), p_json_parameters.get_string('serviceName'), l_debug_plugin).to_clob;

  end connect_to_plugin_server;

  procedure deregister_plugin_server
  (
    p_plugin_server                   plugin_servers.plugin_server%type
  )

  is

  begin

    delete from plugin_modules where plugin_server = p_plugin_server;
    delete from plugin_servers where plugin_server = p_plugin_server;

  end deregister_plugin_server;

  function determine_heartbeat_status
  (
    p_heartbeat_timestamp             plugin_servers.heartbeat_timestamp%type,
    p_heartbeat_interval              plugin_servers.heartbeat_interval%type
  )
  return varchar2

  is

    l_seconds                         pls_integer;

  begin

    l_seconds := round((cast(systimestamp at time zone 'utc' as date) - cast(p_heartbeat_timestamp as date)) *  86400);


    if l_seconds > p_heartbeat_interval then

      return 'no pulse';

    end if;

    return 'pulse detected';

  end determine_heartbeat_status;

  procedure disconnect_from_plugin_server
  (
    p_json_parameters                 json_object_t
  )

  is

    l_plugin_process                  json_object_t;
    l_message_payload                 json_object_t := json_object_t;

  begin

--  This may seem like a hack but it in fact shows how we can use the flexibility of JSON to make a determination...

    l_plugin_process := db_twig.get_object(p_json_parameters, 'pluginProcess', null);
    if l_plugin_process is null then

      l_plugin_process := p_json_parameters;

    end if;

    l_message_payload.put('pluginProcessId', db_twig.get_number(l_plugin_process, 'pluginProcessId'));
    l_message_payload.put('messageType', dbplugin_api.DISCONNECT_FROM_PLUGIN_MSG);

    send_msg_to_plugin_server(l_plugin_process.get_string('pluginServer'), l_message_payload);
    l_message_payload := get_msg_for_plugin_client;

  end disconnect_from_plugin_server;

  function execute_python_script
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_plugin_process                  json_object_t := db_twig.get_object(p_json_parameters, 'pluginProcess');
    l_timeout_value                   pls_integer := db_twig.get_number(p_json_parameters, 'timeout', null);
--    l_script_object_id                vault_objects.object_id%type := db_twig.get_string(p_json_parameters, 'pythonScriptId');
    l_json_parameters                 json_object_t := json_object_t;
    l_python_script                   varchar2(256) := db_twig.get_string(p_json_parameters, 'pythonScript');
    l_requesting_service              db_twig_services.service_name%type := db_twig.get_string(p_json_parameters, 'requestingService');
    l_json_object                     json_object_t;

  begin

/*    l_python_script := digital_bunker.generate_object_filename(p_object_id => l_script_object_id,
      p_access_mode => dgbunker_service.READ_ACCESS, p_gateway_name => l_plugin_process.get_string('pluginServer'),
      p_valid_until => dgbunker_service.VALID_FOR_AN_HOUR, p_access_limit => 2);

    commit; */

    l_json_parameters.put('pythonScript', l_python_script);
    l_json_parameters.put('pythonParameters', db_twig.get_clob(p_json_parameters, 'parameterString'));

    l_json_object := call_plugin(l_plugin_process, null, l_json_parameters, l_timeout_value);
    return l_json_object.to_clob;

  end execute_python_script;

  function get_plugin_modules
  (
    p_plugin_server                   plugin_modules.plugin_server%type
  )
  return clob

  is

    l_clob                            clob;

  begin

    select  nvl(json_arrayagg(json_object('pluginModule' is plugin_module)), '[]')
      into  l_clob
      from  plugin_modules
     where  plugin_server = p_plugin_server;

    return l_clob;

  end get_plugin_modules;

  function get_plugin_server
  (
    p_plugin_module                   plugin_modules.plugin_module%type
  )
  return varchar2

  is

    l_plugin_server                   plugin_servers.plugin_server%type;

  begin

    select  plugin_server
      into  l_plugin_server
      from  plugin_modules
     where  upper(plugin_module) = upper(p_plugin_module)
       and  rownum = 1;

    return l_plugin_server;

  exception

  when no_data_found then

    raise_application_error(PLUGIN_SERVER_ERROR, 'Requested plugin is not available: ' || p_plugin_module);

  end get_plugin_server;

  function get_plugin_servers return json_array_t

  is

    l_plugin_servers                  json_array_t := json_array_t;
    l_plugin_modules                  json_array_t;
    l_plugin_server                   json_object_t;

  begin

    for plugin_row in
    (
      select  plugin_server, support_info, dbplugin_api.get_plugin_modules(plugin_server) plugin_modules
        from  plugin_servers
    )
    loop

      l_plugin_server := json_object_t(substr(plugin_row.support_info, 1, 1)||'"pluginServer":"'||plugin_row.plugin_server||'",'||substr(plugin_row.support_info, 2));
      l_plugin_modules := json_array_t(plugin_row.plugin_modules);
      l_plugin_server.put('pluginModules', l_plugin_modules);
      l_plugin_servers.append(l_plugin_server);

    end loop;

    return l_plugin_servers;

  end get_plugin_servers;

  function get_plugin_server_status
  (
    p_plugin_server                   plugin_servers.plugin_server%type
  )
  return clob

  is

    l_clob                            clob;
    l_server_status                   varchar2(128);

  begin

    begin

      select  'online'
        into  l_server_status
        from  plugin_servers
       where  plugin_server = p_plugin_server;

    exception

    when no_data_found then

      select  json_object(
                'pluginServer' is p_plugin_server,
                'serverStatus' is 'offline' returning clob)
        into  l_clob
        from  dual;

      return l_clob;

    end;

    select  json_object(
              'pluginServer' is plugin_server,
              'serverStatus' is l_server_status,
              'lastActivity' is to_char((trunc(cast(last_activity_timestamp as date) - to_date('01-Jan-1970')) * 86400) +
                to_char(last_activity_timestamp, 'sssss')) || '.' || to_char(last_activity_timestamp, 'FF6'),
              'heartbeat' is to_char((trunc(cast(heartbeat_timestamp as date) - to_date('01-Jan-1970')) * 86400) +
                to_char(heartbeat_timestamp, 'sssss')) || '.' || to_char(heartbeat_timestamp, 'FF6'),
              'heartbeatInterval' is heartbeat_interval,
              'heartbeatStatus' is determine_heartbeat_status(heartbeat_timestamp, heartbeat_interval)
              returning clob)
      into  l_clob
      from  plugin_servers
     where  plugin_server = p_plugin_server;

    return l_clob;

  end get_plugin_server_status;

  function get_status_of_all_servers

  return clob

  is

    l_clob                            clob;

  begin

    select  json_arrayagg(json_object(
              'pluginServer' is plugin_server,
              'lastActivity' is to_char((trunc(cast(last_activity_timestamp as date) - to_date('01-Jan-1970')) * 86400) +
                to_char(last_activity_timestamp, 'sssss')) || '.' || to_char(last_activity_timestamp, 'FF6'),
              'heartbeat' is to_char((trunc(cast(heartbeat_timestamp as date) - to_date('01-Jan-1970')) * 86400) +
                to_char(heartbeat_timestamp, 'sssss')) || '.' || to_char(heartbeat_timestamp, 'FF6'),
              'heartbeatInterval' is heartbeat_interval,
              'heartbeatStatus' is determine_heartbeat_status(heartbeat_timestamp, heartbeat_interval)
              returning clob))
      into  l_clob
      from  plugin_servers;

    return l_clob;

  end get_status_of_all_servers;

  procedure shutdown_plugin_server
  (
    p_plugin_server                   plugin_servers.plugin_server%type,
    p_shutdown_mode                   pls_integer default dbplugin_api.IMMEDIATE_SHUTDOWN
  )

  is

    l_payload                         json_object_t := json_object_t;

  begin

/*    message := plugin$message_t(dbms_session.unique_session_id, p_shutdown_mode,
      p_plugin_server, null, null, null, null, null, null); */

/*    l_json_parameters.
    dbplugin_api.enqueue_plugin$server_message(message); */

    l_payload.put('messageType', p_shutdown_mode);
    send_msg_to_plugin_server(p_plugin_server, l_payload);

  end shutdown_plugin_server;

/*  procedure update_last_activity
  (
    p_plugin_server                              plugin_servers.plugin_server%type
  )

  is

  begin

    update  plugin_servers
       set  last_activity_timestamp = systimestamp at time zone 'utc'
     where  plugin_server = p_plugin_server;

  end update_last_activity;

  procedure update_server_heartbeat
  (
    p_plugin_server                              plugin_servers.plugin_server%type
  )

  is

  begin

    update  plugin_servers
       set  heartbeat_timestamp = systimestamp at time zone 'utc'
     where  plugin_server = p_plugin_server;

  end update_server_heartbeat; */


end dbplugin_api;
/
show errors package body dbplugin_api
