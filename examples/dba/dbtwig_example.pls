create or replace
package body dbtwig_example as

  s_api_token                         varchar2(32) := '%api-token%';              --  Store your AsterionDB API Token here.

  SERVICE_NAME                        constant varchar2(13) := 'dbTwigExample';

  function generate_object_weblink
  (
    l_object_id                       varchar2
  )
  return clob

  is

    l_json_data                       json_object_t;

  begin

    l_json_data := json_object_t(dgbunker_service.generate_object_weblink(s_api_token, l_object_id, dgbunker_service.STREAM_CONTENT));
    return l_json_data.get_string('objectWeblink');

  end generate_object_weblink;

---
---
---

  procedure create_dbtwig_example_service

  is

  begin

    db_twig.create_dbtwig_service(p_service_name => SERVICE_NAME, p_service_owner => sys_context('USERENV', 'CURRENT_USER'),
      p_session_validation_procedure => 'dbtwig_example.validate_session');

  end create_dbtwig_example_service;

  procedure edit_spreadsheet
  (
    p_json_parameters                 json_object_t
  )

  is

    l_json_object                     json_object_t;
    l_spreadsheet_id                  maintenance_manuals.spreadsheet_id%type :=
      db_twig.get_string_parameter(p_json_parameters, 'spreadsheetId');
    l_spreadsheet_file                varchar2(256);

  begin

--  Generate a filename that we can use with LibreOffice

    l_json_object := json_object_t(dgbunker_service.generate_object_filename(p_session_id => s_api_token, p_gateway_name => sys_context('userenv', 'host'),
      p_object_id => l_spreadsheet_id, p_access_mode => dgbunker_service.READ_WRITE_ACCESS, p_access_limit => dgbunker_service.UNLIMITED_ACCESS_OPERATIONS,
      p_valid_until => dgbunker_service.VALID_FOR_AN_HOUR, p_allow_temporary_files => dgbunker_service.OPTION_ENABLED));

    l_spreadsheet_file := l_json_object.get_string('filename');

--  Gotta commit this so the external process (libreoffice and DbObscura) can see our transaction...

    commit;

    dgbunker_service.spawn_helper_application(sys_context('userenv', 'host'), 'libreoffice '||l_spreadsheet_file);

  end edit_spreadsheet;

/*

  This function is called by DbTwig on behalf of the DbTwig Example Web Application.

  We are using Oracle's built-in capabilities to generate a JSON string directly from a SELECT statement.

  Note how we are generating the assemblyPhotos item.  By embedding a function within the SELECT statement,
  we can generate master/detail information in a single call.

  We have also provided the needed modifications as commented out SELECT items to help speed up the process
  of converting this example so that it is accessing unstructured data from AsterionDB.

  Execute the following SQL statement to modify the maintenance_manuals table:

    alter table maintenance_manuals add object_id varchar2(32);

*/

  function get_maintenance_manual_detail
  (
    p_json_parameters                 json_object_t
  )
  return clob

  as

    l_manual_id                       maintenance_manuals.manual_id%type := db_twig.get_number_parameter(p_json_parameters, 'manualId');
    l_clob                            clob;

  begin

    select  json_object(
              'manufacturer' is manufacturer,
              'inServiceFrom' is to_char(in_service_from, 'dd-MON-yyyy'),
              'maintenanceDivision' is maintenance_division,
              'revisionNumber' is revision_number,
--              'maintenanceManualLink' is generate_object_weblink(object_id),
--              'oldMaintenanceManualLink' is maintenance_manual_filename,
              'maintenanceManualLink' is maintenance_manual_filename,
              'spreadsheetId' is spreadsheet_id,
              'assemblyPhotos' is get_major_assembly_photos(l_manual_id) format json
              returning clob)
      into  l_clob
      from  maintenance_manuals
     where  manual_id = l_manual_id;

    return l_clob;

  end get_maintenance_manual_detail;

/*

  This function is called by get_maintenance_manual_detail. It will provide all of the photographs associated with
  an mainteance manual by returning a JSON string.

  We have provided the needed modifications as commented out SELECT items to help speed up the process of converting
  this example so that it is accessing unstructured data from AsterionDB.

  Execute the following SQL statement to modify the major_assembly_photos table:

    alter table major_assembly_photos add object_id varchar2(32);

*/

  function get_major_assembly_photos
  (
    p_manual_id                       maintenance_manuals.manual_id%type
  )
  return clob

  as

    l_clob                            clob;

  begin

    select  json_arrayagg(json_object(
--              'mediaLink' is generate_object_weblink(object_id),
--              'oldMediaLink' is filename)
              'mediaLink' is filename)
              returning clob)
      into  l_clob
      from  major_assembly_photos
     where  manual_id = p_manual_id;

    return l_clob;

  end get_major_assembly_photos;

/*

  This function is called by DbTwig on behalf of the DbTwig Example Web Application.

  Note that even though we do not need any parameters, we still have to provide the required function/procedure signature.

*/

  function get_maintenance_manuals
  (
    p_json_parameters	              json_object_t
  )
  return clob

  as

    l_clob                            clob;

  begin

    select  json_arrayagg(json_object(
              'manufacturer' is manufacturer,
              'manualId' is manual_id,
              'inServiceFrom' is to_char(in_service_from, 'dd-MON-yyyy'))
              order by manufacturer returning clob)
      into  l_clob
      from  maintenance_manuals;

    return l_clob;

  end get_maintenance_manuals;

/*

 Simple code that shows you how to unpack the parameter object and insert values into the DB.

*/

  procedure save_tech_note
  (
    p_json_parameters                 json_object_t
  )

  is

    l_tech_note                       technician_notes.tech_note%type := db_twig.get_string_parameter(p_json_parameters, 'techNote');
    l_manual_id                       maintenance_manuals.manual_id%type := db_twig.get_number_parameter(p_json_parameters, 'manualId');

  begin

    insert into technician_notes
      (manual_id, tech_note)
    values
      (l_manual_id, l_tech_note);

  end save_tech_note;

/*

 This is just a placeholder procedure in order to satisfy DbTwig's requirement for a session_validation_procedure.

*/

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  )

  is

  begin

    null;

  end validate_session;

end dbtwig_example;
/
show errors package body dbtwig_example
