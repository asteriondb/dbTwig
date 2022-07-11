/******************************************************************************
 *                                                                            *
 *  Copyleft (:-) 2020, 2022 by AsterionDB Inc.                               *
 *                                                                            *
 *  DbTwig client-layer adapter.                                              *
 *                                                                            *
 *  This software demonstrates a method of interfacing to the DbTwig middle   *
 *  tier listener and underlying data-layer logic.                            *
 *                                                                            *
 *  We encourage you to copy/paste this file into your project and modify to  *
 *  suit your needs.                                                          *
 *                                                                            *
 *  No rights claimed or implied. This software is not to be used in a        *
 *  production setting without modifcation and customization by the end user. *
 *  End user accepts all responsibilities by using this software as a basis   *
 *  for development and instruction.                                          *
 *                                                                            *
 *  This software is not claimed to be, nor guaranteed to be free from defect *
 *  or error.                                                                 *
 *                                                                            *
 *  This software is to be used by the end user as a basis for instruction    *
 *  and as a template for implementation in production use cases.             *
 *                                                                            *
 *  End users are not required to post their modifications for others to use. *
 *                                                                            *
 *  This software is un-licensed and free to use in any manner you choose.    *
 *                                                                            *
 *****************************************************************************/
  
//  Oracle reserves error numbers ranging from 20000 to 20999 for end-user use.
//  Actually, the values run from -20000 to -20999 in the database but by the
//  time they get all the way out from the database's error handlers, the values
//  get converted to positive values.

//  It is useful to have a class of error numbers that will trigger a 
//  fatal-error.  Fatal errors usually result in killing the user-session and 
//  redirecting the browser.
//
//  The error values here are suggestions only.
    
const FatalErrorFloor = 20001;
const FatalErrorCeiling = 20099;

//  It's also useful to have exported constant variables that correllate to 
//  your user defined exceptions and error codes.  Here's a commented out 
//  example:

//  export const UsernameExists = 20117;

//  The standard URL format for the DbTwig middle-tier listener is 
//  '/dbTwig/{db-twig-service}/'.  Note the closing slash character.

const restAPI = '/dbTwig/reactExample/';

//  Build an appropriate URL.  You can alter this to suite your needs.
//  The global variable window.dbTwigHost is set in the configuration file
//  ./public/assets/config.js, if you have one.  Be sure to run 'npm run build'
//  after modifying config.js.

function buildURL(path, parameters)
{

  //  If window.dbTwigHost is set, use that value when constructing the URL.
  //  Otherwise, use port 8080 at the current location from where the ReactExample 
  //  is being served from as the location of the DbTwig middle-tier listener.

  let apiURL = (window.dbTwigHost !== null ? 
    window.dbTwigHost + restAPI : 
    window.location.protocol + '//' + window.location.hostname  + ':8080' + restAPI);

  if (typeof parameters === 'undefined')
    return apiURL + path;
  else
    return apiURL + path + parameters;
}

//  This is a generic error handler.  We have wired it into global UI components
//  that are defined in ReactExample.js.  If you want to do something different,
//  go ahead!
//
//  In most cases, this generic error handler will suffice but if you need to do
//  something fancy you can write a specific error handler within your 
//  application's code (e.g. after calling dbTwig.callRestAPI).

export function apiErrorHandler(result, errorMessage)
{
  switch (result.status)
  {
    case 'httpError':
      window.postNotification('error', result.errorMessage);
      return;

    case 'fatalError':
      console.log('We recommend that you terminate your user sesion when a fatal error is detected.')
      window.location.replace(window.redirectURI);
      return;
      
    default:
      window.openAppModal(errorMessage, result.errorMessage);
      return;
  }
}

//  Here's where it all happens!!!  Call this function with the following 
//  (or similar) syntax:
//
//    let result = await this.dbTwig.callRestAPI('getInsuranceClaimDetail', bodyData);
//    if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to fetch insurance claims.');
//
//  While we do not expect to change the call-syntax to the DbTwig middle-tier,
//  if a change is necessary, it will most likely be implemented by doing a
//  search and replace.

export async function callRestAPI(entryPoint, bodyData)
{
  //  If you need to add any additional headers (e.g. session token) do that
  //  here by adding more properties to the headers object.

  let headers = { 'Content-Type': 'application/json'};

  //  Create an appropriate request object.

  let request = (undefined === bodyData ? 
    new Request(buildURL(entryPoint), {headers: new Headers(headers)}) :
    new Request(buildURL(entryPoint), {method: "POST", body: JSON.stringify(bodyData), headers: new Headers(headers)}));

  let response = await fetch(request).catch(function(error)
  {
    return {status: 'httpError', errorMessage: 'Lost connection to server - ' + error};
  });

  //  If we can't talk to the restAPI, we'll get an httpError from the catch
  //  block above.

  if ('httpError' === response.status) return response;

  let errorMsg = "Server response not understood.  Consult the system & framework error logs for further information.";

  //  If the DbTwig middle-tier listener returns something other than success
  //  the JSON data will contain our error info.

  if (!response.ok)
  {
    //  Sanity checking....
    if (response.headers.has('Content-Type') && response.headers.get('Content-Type') === 'application/json; charset=utf-8')
    {
      let jsonData = await response.json();

      //  Another sanity check.
      if (typeof jsonData.errorCode === 'undefined') return {status: 'fatalError'};

      //  If the data-layer has generated a fatal error, handle that immediately.
      //  Note, fatal errors (which are not supposed to happen) do not generate 
      //  any additional info.
      if (jsonData.errorCode >= FatalErrorFloor && jsonData.errorCode <= FatalErrorCeiling)
        return {status: 'fatalError'};
      else
        return {status: 'apiError', ...jsonData};
    }
    else
      //  Something is out of sync.  Just send a generic message.
      return {status: 'httpError', errorMessage: errorMsg}
  }     

  //  Sanity check....
  if (response.headers.has('Content-Type') && response.headers.get('Content-Type') === 'application/json; charset=utf-8')
  {
    let jsonData = await response.json();
    return {status: 'success', jsonData: jsonData};
  }
  else
    return {status: 'jsonFailure', errorMessage: 'Invalid content type: ' + response.headers.get('Content-Type')};
}
