create or replace
package dbplugin_api as

/*

Copyright 2014 - 2025 by AsterionDB, Inc. All rights reserved.

*/

  SERVER_QUEUE                        CONSTANT varchar2(30) := 'plugin$server';

  DEFAULT_TIMEOUT                     CONSTANT pls_integer := 30;

  MESSAGE_EXPIRATION                  CONSTANT pls_integer := 5;
  ONE_MINUTE                          CONSTANT pls_integer := 60;

  NORMAL_SHUTDOWN                     CONSTANT pls_integer := 5;
  IMMEDIATE_SHUTDOWN                  CONSTANT pls_integer := 10;

  DEBUG_PLUGIN                        CONSTANT boolean := true;

  CURL_PLUGIN_MODULE                  constant plugin_modules.plugin_module%type := 'curlClient';
  SMTP_PLUGIN_MODULE                  constant plugin_modules.plugin_module%type := 'smtpClient';
  PYTHON_SCRIPT_RUNNER                constant plugin_modules.plugin_module%type := 'pythonScriptRunner';
  FFPROBE_PLUGIN_MODULE               constant plugin_modules.plugin_module%type := 'ffprobe';

/*
  call_plugin

  Call a function in a plugin module.  Note that you have to call the connect_to_plugin function first.
*/

  function call_plugin
  (
    p_plugin_process                  json_object_t,
    p_function                        varchar2,
    p_json_parameters                 json_object_t default null,
    p_timeout_value                   pls_integer default null
  )
  return json_object_t;

/*
  connect_to_plugin_server

  Connect to a specific plugin.  This function must be called before the  call_plugin procedure.  The
  disconnect_from_plugin function must be called when the connection to the plugin module is no longer needed.

  Save the JSON value returned by this function. It must be used when communicating with the plugin.

  To debug your plugin module call this procedure with the debug_plugin argument set to true.  Upon calling this
  procedure, start your debugger and run the pluginDriver program with a '-d' parameter value.

*/

  function connect_to_plugin_server
  (
    p_plugin_module                   plugin_modules.plugin_module%type,
    p_service_name                    varchar2,
    p_debug_plugin                    boolean default false
  )
  return json_object_t;

/*
  connect_to_plugin

  Equivalent function that is mapped to DbTwig.

*/

  function connect_to_plugin_server
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*
  determine_heartbeat_status

  Called when retrieving the plugin server's status.
*/
  function determine_heartbeat_status
  (
    p_heartbeat_timestamp             plugin_servers.heartbeat_timestamp%type,
    p_heartbeat_interval              plugin_servers.heartbeat_interval%type
  )
  return varchar2;

/*
  disconnect_from_plugin

  A user application calls the disconnect_from_plugin procedure when the services of a plugin are no longer needed.

*/

  procedure disconnect_from_plugin_server
  (
    p_json_parameters                 json_object_t
  );

/*

  execute_python_script

*/

  function execute_python_script
  (
    p_json_parameters                 json_object_t
  )
  return clob;

/*

  get_plugin_server

  This function will return a plugin server that is capable of processing requests for the specified plugin service.

*/

  function get_plugin_server
  (
    p_plugin_module                   plugin_modules.plugin_module%type
  )
  return varchar2;

/*

  get_plugin_server_status

  This function will return JSON object with plugin server status values.

*/

  function get_plugin_server_status
  (
    p_plugin_server                   plugin_servers.plugin_server%type
  )
  return clob;

/*

  get_status_of_all_servers

  This function will return an array of json objects containing the status info for all plugin servers.

*/

  function get_status_of_all_servers return clob;

/*
  shutdown_plugin_server

  The shutdown_plugin_server procedure allows an administrator to shutdown a specific plugin server from a remote
  location.

  The plugin_server parameter specifies the name of the plugin server that will be shutdown.

  The shutdown_mode parameter allows an administrator to specify the method used when shutting down a plugin server.
  IMMEDIATE_SHUTDOWN shuts down the plugin server immediately.  NORMAL_SHUTDOWN causes the plugin server to refuse new
  plugin connection requests and shuts down the plugin server once all connecitons have been terminated.
*/

  procedure shutdown_plugin_server
  (
    p_plugin_server                              plugin_servers.plugin_server%type,
    p_shutdown_mode                              pls_integer default dbplugin_api.IMMEDIATE_SHUTDOWN
  );

end dbplugin_api;
.
/
show errors package dbplugin_api
