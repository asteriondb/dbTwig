create or replace
function call_restapi
(
  p_json_parameters                   clob
)
return clob

is

begin

  return db_twig.call_restapi(p_json_parameters);

end call_restapi;
.
/
show errors function call_restapi
