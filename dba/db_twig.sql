create or replace
package db_twig as

  function call_rest_api
  (
    p_json_parameters                 clob
  )
  return clob;

end db_twig;
.
/
show errors package db_twig
