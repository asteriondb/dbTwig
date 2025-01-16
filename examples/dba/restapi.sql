create or replace
package restapi as

  procedure edit_spreadsheet
  (
    p_json_parameters                 json_object_t
  );

  function get_maintenance_manual_detail
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  function get_maintenance_manuals
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  procedure save_tech_note
  (
    p_json_parameters                 json_object_t
  );

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  );

end restapi;
.
/
show errors package restapi
