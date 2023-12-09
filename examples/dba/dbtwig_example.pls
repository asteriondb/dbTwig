create or replace
package body dbtwig_example as

  s_api_token                         varchar2(32) := '%api-token%';              --  Store your AsterionDB API Token here.

  function get_number_parameter_value                                             -- Parameter getter/checker w/ default value
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required_parameter              boolean default true,                       -- Set to false to allow the parameter to not be required
    p_default_value                   number default null                         -- Set to a default value other than null when parameter is not required
  )
  return number

  is

  begin

    if p_json_parameters.has(p_key) then

      return p_json_parameters.get_number(p_key);

    else

      if p_required_parameter then

        raise_application_error(-20000, 'A required parameter was not specified.');

      else

        return p_default_value;

      end if;

    end if;

  end get_number_parameter_value;

  function get_string_parameter_value                                             -- Parameter getter/checker w/ default value
  (
    p_json_parameters                 json_object_t,
    p_key                             varchar2,
    p_required_parameter              boolean default true,                       -- Set to false to allow the parameter to not be required
    p_default_value                   varchar2 default null                       -- Set to a default value other than null when parameter is not required
  )
  return varchar2

  is

  begin

    if p_json_parameters.has(p_key) then

      return p_json_parameters.get_string(p_key);

    else

      if p_required_parameter then

        raise_application_error(-20000, 'A required parameter was not specified.');

      else

        return p_default_value;

      end if;

    end if;

  end get_string_parameter_value;

/*

  Applications that interface to AsterionDB as an API client send and receive JSON data. Create a JSON object that will hold
  our parameters and make a call to DbTwig to generate a weblink.

*/

  function generate_object_weblink
  (
    l_object_id                       varchar2
  )
  return clob

  is

    l_json_object                     json_object_t := json_object_t;
    l_json_data                       json_object_t;

  begin

    l_json_object.put('entryPoint', 'generateObjectWeblink');
    l_json_object.put('serviceName', 'asterionDB');
    l_json_object.put('sessionId', s_api_token);
    l_json_object.put('contentDisposition', 'STREAM');
    l_json_object.put('objectId', l_object_id);

    l_json_data := json_object_t(db_twig.call_rest_api(l_json_object.to_clob));
    return l_json_data.get_string('objectWeblink');

  end generate_object_weblink;

---
---
---

  procedure edit_spreadsheet
  (
    p_json_parameters                 json_object_t
  )

  is

    l_json_object                     json_object_t;
    l_spreadsheet_id                  maintenance_manuals.spreadsheet_id%type :=
      get_string_parameter_value(p_json_parameters, 'spreadsheetId');
    l_spreadsheet_file                varchar2(256);
    l_result                          json_object_t;

  begin

--  Generate a filename that we can use with LibreOffice

    l_json_object := json_object_t;
    l_json_object.put('entryPoint', 'generateObjectFilename');
    l_json_object.put('serviceName', 'asterionDB');
    l_json_object.put('sessionId', s_api_token);
    l_json_object.put('gatewayName', sys_context('userenv', 'host'));
    l_json_object.put('objectId', l_spreadsheet_id);
    l_json_object.put('accessMode', 'U');
    l_json_object.put('accessLimit', -1);
    l_json_object.put('validUntil', '1 Hour');
    l_json_object.put('allowTempFile', 'Y');

    l_result := json_object_t(db_twig.call_rest_api(l_json_object.to_clob));
    l_spreadsheet_file := l_result.get_string('filename');


--  Gotta commit this so the external process (the Python script and DbObscura) can see our transaction...

    commit;

    l_json_object := json_object_t;
    l_json_object.put('entryPoint', 'spawnHelperApplication');
    l_json_object.put('serviceName', 'asterionDB');
    l_json_object.put('sessionId', s_api_token);
    l_json_object.put('gatewayName', sys_context('userenv', 'host'));
    l_json_object.put('commandLine', 'libreoffice '||l_spreadsheet_file);

    l_result := json_object_t(db_twig.call_rest_api(l_json_object.to_clob));

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

    l_manual_id                       maintenance_manuals.manual_id%type := get_number_parameter_value(p_json_parameters, 'manualId');
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

  Execute the following SQL statement to modify the maintenance_manual_photos table:

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

  This function is called directly by DbTwig upon encountering an exception.

*/

  function restapi_error
  (
    p_json_parameters                 clob
  )
  return json_object_t

  is

    l_json_object                     json_object_t := json_object_t;
    l_error_id                        varchar2(12) := 'random-value';

  begin

-- Do something here such as log the error in a table, create a real errorId. Get error stack info by calling utl_call_stack.

    l_json_object.put('errorId', l_error_id);
    return l_json_object;

  end restapi_error;

/*

 Simple code that shows you how to unpack the parameter object and insert values into the DB.

*/

  procedure save_tech_note
  (
    p_json_parameters                 json_object_t
  )

  is

    l_tech_note                       technician_notes.tech_note%type := get_string_parameter_value(p_json_parameters, 'techNote');
    l_manual_id                       maintenance_manuals.manual_id%type := get_number_parameter_value(p_json_parameters, 'manualId');

  begin

    insert into technician_notes
      (manual_id, tech_note)
    values
      (l_manual_id, l_tech_note);

  end save_tech_note;

/*

 This is just a placeholder procedure in order to satisfy DbTwig's requirements  for a session_validation_procedure.

*/

  procedure validate_session
  (
    p_entry_point                     middle_tier_map.entry_point%type,
    p_json_parameters                 json_object_t
  )

  is

  begin

    null;

  end validate_session;

end dbtwig_example;
/
show errors package body dbtwig_example
