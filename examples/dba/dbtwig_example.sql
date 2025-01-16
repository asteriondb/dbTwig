create or replace
package dbtwig_example as

  procedure create_dbtwig_example_service;

  procedure edit_spreadsheet
  (
    p_spreadsheet_id                  maintenance_manuals.spreadsheet_id%type
  );

  function generate_object_weblink
  (
    p_object_id                       varchar2
  )
  return clob;

  function get_maintenance_manual_detail
  (
    p_manual_id                       maintenance_manuals.manual_id%type
  )
  return clob;

  function get_major_assembly_photos
  (
    p_manual_id                       maintenance_manuals.manual_id%type
  )
  return clob;

  function get_maintenance_manuals return clob;

  procedure save_tech_note
  (
    p_tech_note                       technician_notes.tech_note%type,
    p_manual_id                       maintenance_manuals.manual_id%type
  );

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  );

end dbtwig_example;
.
/
show errors package dbtwig_example
