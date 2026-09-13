create or replace
package body dbplugin_runtime_api as

  s_user_error_max                    constant pls_integer := -20000;
  s_user_error_min                    constant pls_integer := -20999;

  s_plugin_server_queue_name          varchar2(256) := sys_context('USERENV', 'CURRENT_SCHEMA')||'.'||dbplugin_api.SERVER_QUEUE;

  procedure deregister_plugin_server
  (
    p_json_parameters                 json_object_t
  )

  is

    l_plugin_server                   plugin_servers.plugin_server%type := p_json_parameters.get_string('pluginServer');

  begin

    delete from plugin_modules where plugin_server = l_plugin_server;
    delete from plugin_servers where plugin_server = l_plugin_server;

  end deregister_plugin_server;

  function get_msg_for_plugin_server
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_plugin_server                   plugin_servers.plugin_server%type := p_json_parameters.get_string('pluginServer');
    l_dequeue_options                 DBMS_AQ.dequeue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);
    l_payload                         plugin$message_t;

  begin

    l_dequeue_options.wait := dbplugin_api.ONE_MINUTE;    -- DBMS_AQ.FOREVER;
    l_dequeue_options.navigation := DBMS_AQ.FIRST_MESSAGE;
    l_dequeue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_dequeue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_dequeue_options.deq_condition := 'tab.user_data.plugin_server = '''||l_plugin_server||'''';

    dbms_aq.dequeue(queue_name => s_plugin_server_queue_name, dequeue_options => l_dequeue_options,
      message_properties => l_message_properties, payload => l_payload, msgid => l_message_handle);

    return l_payload.message_payload;

  end get_msg_for_plugin_server;

  function get_plugin_info
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_response                        clob;
    l_plugin_server                   plugin_modules.plugin_server%type := p_json_parameters.get_string('pluginServer');
    l_plugin_module                   plugin_modules.plugin_module%type := p_json_parameters.get_string('pluginModule');

  begin

    select  json_object('driverName' is driver_name,
                        'libraryName' is library_name,
                        'status' is 'success')
      into  l_response
      from  plugin_modules
     where  plugin_module = l_plugin_module
       and  plugin_server = l_plugin_server;

    return l_response;

  end get_plugin_info;

  procedure recreate_queue

  is

  begin

    dbms_aqadm.stop_queue('PLUGIN$SERVER');
    dbms_aqadm.drop_queue(queue_name => 'PLUGIN$SERVER');
    dbms_aqadm.drop_queue_table(queue_table => 'PLUGIN$SERVER');
    dbms_aqadm.create_queue_table(queue_table => 'plugin$server', queue_payload_type => 'plugin$message_t');
    dbms_aqadm.create_queue(queue_name => 'plugin$server', queue_table => 'plugin$server');
    dbms_aqadm.start_queue('plugin$server');

  end recreate_queue;

  procedure register_plugin_module
  (
    p_json_parameters                 json_object_t
  )

  is

    l_plugin_server                   plugin_servers.plugin_server%type := p_json_parameters.get_string('pluginServer');
    l_plugin_module                   plugin_modules.plugin_module%type := p_json_parameters.get_string('pluginModule');
    l_library_name                    plugin_modules.library_name%type := p_json_parameters.get_string('libraryName');
    l_driver_name                     plugin_modules.driver_name%type  := p_json_parameters.get_string('driverName');

  begin

    if l_driver_name is null then

      l_driver_name := 'dbPluginDriver';

    end if;

    insert into plugin_modules values (l_plugin_server, l_plugin_module, l_driver_name, l_library_name);

  exception

  when dup_val_on_index then

    raise_application_error(DBPLUGIN_LAYER_ERROR_CODE, 'Module already registered in the database.');

  end register_plugin_module;

  procedure register_plugin_server
  (
    p_json_parameters                 json_object_t
  )

  is

    l_plugin_server                   plugin_servers.plugin_server%type := p_json_parameters.get_string('pluginServer');
    l_heartbeat_interval              plugin_servers.heartbeat_interval%type := p_json_parameters.get_number('heartbeatInterval');
    l_git_tag                         varchar2(10) := p_json_parameters.get_string('gitTag');
    l_git_branch                      varchar2(10):= p_json_parameters.get_string('gitBranch');
    l_build_date                      varchar2(11) := p_json_parameters.get_string('buildDate');
    l_build_time                      varchar2(8) := p_json_parameters.get_string('buildTime');
    l_json_object                     json_object_t := json_object_t;
    l_support_info                    clob;

  begin

    l_json_object.put('gitTag', l_git_tag);
    l_json_object.put('gitBranch', l_git_branch);
    l_json_object.put('buildDate', l_build_date);
    l_json_object.put('buildTime', l_build_time);
    l_support_info := l_json_object.to_clob;

    insert into plugin_servers
      (plugin_server, ip_address, support_info, heartbeat_timestamp, heartbeat_interval)
    values
      (l_plugin_server, sys_context('userenv', 'ip_address'), l_support_info, systimestamp at time zone 'utc',
       l_heartbeat_interval);

  exception

  when dup_val_on_index then

    delete
      from  plugin_modules
     where  plugin_server = l_plugin_server;

    update  plugin_servers
       set  ip_address = sys_context('userenv', 'ip_address'),
            support_info = l_support_info,
            heartbeat_timestamp = systimestamp at time zone 'utc',
            heartbeat_interval = l_heartbeat_interval
     where  plugin_server = l_plugin_server;

  end register_plugin_server;

  procedure send_msg_to_plugin_client
  (
    p_json_parameters                 json_object_t
  )

  is

/*    l_payload                         json := p_json_parameters.to_json;
    l_client_handle                   varchar2(24) := p_json_parameters.get_string('clientHandle');
    l_message_type                    pls_integer := p_json_parameters.get_number('messageType');
    l_plugin_server                   plugin_servers.plugin_server%type := p_json_parameters.get_string('pluginServer');
    l_plugin_process_id               number(7) := p_json_parameters.get_number('pluginProcessId');
    l_exception_value                 pls_integer := p_json_parameters.get_number('exceptionValue');
    l_more_messages                   varchar2(1) := p_json_parameters.get_string('moreMessages');
    l_response_data                   varchar2(4000) := p_json_parameters.get_string('responseData'); */

    l_payload                         plugin$message_t := plugin$message_t(p_json_parameters.get_string('clientHandle'), null, p_json_parameters.to_clob);
    l_enqueue_options                 DBMS_AQ.enqueue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);

  begin

/*    l_message := plugin$message_t(l_client_handle, l_message_type, l_plugin_server,  l_plugin_process_id, null, null,
      l_exception_value, l_more_messages, l_response_data); */

    l_message_properties.expiration := dbplugin_api.MESSAGE_EXPIRATION;
    l_enqueue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_enqueue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_message_properties.delay := DBMS_AQ.NO_DELAY;

    dbms_aq.enqueue(queue_name => s_plugin_server_queue_name, enqueue_options => l_enqueue_options,
      message_properties => l_message_properties, payload => l_payload, msgid => l_message_handle);

  end send_msg_to_plugin_client;

  procedure update_heartbeat
  (
    p_json_parameters                 json_object_t
  )

  is

    l_plugin_server                   plugin_servers.plugin_server%type := p_json_parameters.get_string('pluginServer');

  begin

    update  plugin_servers
       set  heartbeat_timestamp = systimestamp at time zone 'utc'
     where  plugin_server = l_plugin_server;

  end update_heartbeat;

  procedure update_last_activity
  (
    p_json_parameters                 json_object_t
  )

  is

    l_plugin_server                   plugin_servers.plugin_server%type := p_json_parameters.get_string('pluginServer');

  begin

    update  plugin_servers
       set  last_activity_timestamp = systimestamp at time zone 'utc'
     where  plugin_server = l_plugin_server;

  end update_last_activity;

---
---
---

  function call_api
  (
    p_json_parameters                 clob
  )
  return clob

  is

    l_json_parameters                 json_object_t := json_object_t(p_json_parameters);
    l_entry_point                     varchar2(30) := l_json_parameters.get_string('entryPoint');
    l_json_response                   clob := '{"status": "success"}';

  begin

    case l_entry_point

      when 'deregisterPluginServer' then

        deregister_plugin_server(l_json_parameters);

      when 'recreateQueue' then

        recreate_queue;

      when 'getPluginInfo' then

        l_json_response := get_plugin_info(l_json_parameters);

      when 'getMsgForPluginServer' then

        l_json_response := get_msg_for_plugin_server(l_json_parameters);

      when 'registerPluginModule' then

        register_plugin_module(l_json_parameters);

      when 'registerPluginServer' then

        register_plugin_server(l_json_parameters);

      when 'sendMsgToPluginClient' then

        send_msg_to_plugin_client(l_json_parameters);

      when 'updateHeartbeat' then

        update_heartbeat(l_json_parameters);

      when 'updateLastActivity' then

        update_last_activity(l_json_parameters);

      else

        l_json_response := '{"status": "failure", "entryPoint": "'||l_entry_point||'"}';

    end case;

    return l_json_response;

  end call_api;

end dbplugin_runtime_api;
/
show errors package body dbplugin_api
