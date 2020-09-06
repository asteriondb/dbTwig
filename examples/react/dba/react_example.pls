create or replace
package body react_example as

  s_api_token                         varchar2(32) := '<ASTERIONDB_API_TOKEN>';

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
    l_json_object.put('authorization', 'Bearer '||s_api_token);
    l_json_object.put('contentDisposition', 'STREAM');
    l_json_object.put('objectId', l_object_id);

    l_json_data := json_object_t(db_twig.call_rest_api(l_json_object.to_clob));
    return l_json_data.get_string('objectWeblink');

  end generate_object_weblink;

  function get_insurance_claim_detail
  (
    p_json_parameters                 clob
  )
  return clob

  as

    l_json_object                     json_object_t := json_object_t(p_json_parameters);
    l_claim_id                        insurance_claims.claim_id%type;
    l_clob                            clob;

  begin

    l_claim_id := l_json_object.get_number('claimId');

    select  json_object(
              'insuredParty' is insured_party,
              'accidentDate' is to_char(accident_date, 'dd-MON-yyyy'),
              'accidentLocation' is accident_location,
              'deductibleAmount' is deductible_amount,
--              'claimsAdjusterReport' is generate_object_weblink(report_id),
--              'oldClaimsAdjusterReport' is claims_adjuster_report,
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
--              'mediaUrl' is generate_object_weblink(photo_id),
--              'oldMediaUrl' is filename)
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

end react_example;
/
show errors package body react_example
