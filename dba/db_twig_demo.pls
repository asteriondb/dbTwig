create or replace
package body db_twig_demo as

  function error_handler
  (
    p_json_parameters                 clob
  )
  return clob

  as

    l_json_object                     json_object_t := json_object_t(p_json_parameters);
    l_authorization                   varchar2(64) := l_json_object.get_string('authorization');
    l_remote_address                  varchar2(64) := l_json_object.get_string('remoteAddress');
    l_server_address                  varchar2(64) := l_json_object.get_string('serverAddress');
    l_user_agent                      varchar2(256) := l_json_object.get_string('userAgent');
    l_http_host                       varchar2(256) := l_json_object.get_string('httpHost');
    l_debug_mode                      varchar2(1) := l_json_object.get_string('debugMode');
    l_error_code                      pls_integer := l_json_object.get_number('errorCode');
    l_error_text                      clob := l_json_object.get_string('errorText');
    l_error_offset                    pls_integer := l_json_object.get_number('errorOffset');
    l_sql_text                        clob := l_json_object.get_string('sqlText');
    l_script_filename                 varchar2(256) := l_json_object.get_string('scriptFilename');
    l_function_name                   varchar2(128) := l_json_object.get_string('functionName');
    l_request_uri                     varchar2(512) := l_json_object.get_string('requestUri');

    l_error_object                    json_object_t := json_object_t;

  begin

    l_error_object.put('errorText', 'Do something with the values that are passed in the json parameter string.');
    return l_error_object.to_clob;

  end error_handler;

  function get_insurance_claim_detail
  (
    p_json_parameters                 clob
  )
  return clob

  as

    l_json_object                     json_object_t := json_object_t(p_json_parameters);

    l_authorization                   varchar2(64) := l_json_object.get_string('authorization');
    l_remote_address                  varchar2(64) := l_json_object.get_string('remoteAddress');
    l_server_address                  varchar2(64) := l_json_object.get_string('serverAddress');
    l_user_agent                      varchar2(256) := l_json_object.get_string('userAgent');
    l_http_host                       varchar2(256) := l_json_object.get_string('httpHost');
    l_debug_mode                      varchar2(1) := l_json_object.get_string('debugMode');

    l_claim_id                        insurance_claims.claim_id%type := l_json_object.get_number('claimId');
    l_clob                            clob;

  begin

    select  json_object(
              'insuredParty' is insured_party,
              'accidentDate' is to_char(accident_date, 'dd-MON-yyyy'),
              'accidentLocation' is accident_location,
              'deductibleAmount' is deductible_amount,
              'claimsAdjusterReport' is claims_adjuster_report,
              'claimPhotos' is get_insurance_claim_photos(l_claim_id) format json
              returning clob)
      into  l_clob
      from  insurance_claims
     where  claim_id = l_claim_id;

    return l_clob;

  end get_insurance_claim_detail;

  function get_insurance_claim_photos
  (
    p_claim_id                        insurance_claims.claim_id%type
  )
  return clob

  as

    l_clob                            clob;

  begin

    select  json_arrayagg(json_object(
              'mediaUrl' is filename)
              returning clob)
      into  l_clob
      from  insurance_claim_photos
     where  claim_id = p_claim_id;

    return l_clob;

  end get_insurance_claim_photos;

  function get_insurance_claims
  (
    p_json_parameters	              clob
  )
  return clob

  as

    l_clob                            clob;

    l_json_object                     json_object_t := json_object_t(p_json_parameters);

    l_authorization                   varchar2(64) := l_json_object.get_string('authorization');
    l_remote_address                  varchar2(64) := l_json_object.get_string('remoteAddress');
    l_server_address                  varchar2(64) := l_json_object.get_string('serverAddress');
    l_user_agent                      varchar2(256) := l_json_object.get_string('userAgent');
    l_http_host                       varchar2(256) := l_json_object.get_string('httpHost');
    l_debug_mode                      varchar2(1) := l_json_object.get_string('debugMode');

  begin

    select  json_arrayagg(json_object(
              'insuredParty' is insured_party,
              'claimId' is claim_id,
              'accidentDate' is to_char(accident_date, 'dd-MON-yyyy'))
              order by insured_party returning clob)
      into  l_clob
      from  insurance_claims;

    return l_clob;

  end get_insurance_claims;

end db_twig_demo;
/
show errors package body db_twig
