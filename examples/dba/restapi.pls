create or replace
package body restapi as

  procedure edit_spreadsheet
  (
    p_json_parameters                 json_object_t
  )

  as

    l_spreadsheet_id                  maintenance_manuals.spreadsheet_id%type :=
        db_twig.get_string_parameter(p_json_parameters, 'spreadsheetId');

  begin

    dbtwig_example.edit_spreadsheet(l_spreadsheet_id);

  end edit_spreadsheet;

  function get_maintenance_manual_detail
  (
    p_json_parameters                 json_object_t
  )
  return clob

  as

    l_manual_id                       maintenance_manuals.manual_id%type := db_twig.get_number_parameter(p_json_parameters, 'manualId');

  begin

    return dbtwig_example.get_maintenance_manual_detail(l_manual_id);

  end get_maintenance_manual_detail;

  function get_maintenance_manuals
  (
    p_json_parameters                 json_object_t
  )
  return clob

  as

  begin

    return dbtwig_example.get_maintenance_manuals;

  end get_maintenance_manuals;

  procedure save_tech_note
  (
    p_json_parameters                 json_object_t
  )

  as

    l_tech_note                       technician_notes.tech_note%type := db_twig.get_string_parameter(p_json_parameters, 'techNote');
    l_manual_id                       maintenance_manuals.manual_id%type := db_twig.get_number_parameter(p_json_parameters, 'manualId');

  begin

    dbtwig_example.save_tech_note(l_tech_note, l_manual_id);

  end save_tech_note;

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  )

  as

  begin
    -- TODO: Implementation required for procedure RESTAPI.validate_session
    null;
  end validate_session;

end restapi;
/
show errors package body restapi
