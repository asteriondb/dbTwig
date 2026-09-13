create or replace
package dbplugin_runtime_api as

  DBPLUGIN_LAYER_ERROR_CODE           CONSTANT pls_integer := -20142;       -- This value is tied to error_logging_pkg.
  DBPLUGIN_LAYER_ERROR                exception;
  pragma exception_init(DBPLUGIN_LAYER_ERROR, DBPLUGIN_LAYER_ERROR_CODE);

  function call_api
  (
    p_json_parameters                 clob
  )
  return clob;

end dbplugin_runtime_api;
.
/
show errors package dbplugin_runtime_api
