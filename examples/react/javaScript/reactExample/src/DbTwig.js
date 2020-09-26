/******************************************************************************
 *                                                                            *
 *  Copyright (c) 2018, 2021 by AsterionDB Inc.                               *
 *                                                                            *
 *  All rights reserved.  No part of this work may be reproduced or otherwise *
 *  incorporated into other works without the express written consent of      *
 *  AsterionDB Inc.                                                           *
 *                                                                            *
 *****************************************************************************/

const FatalErrorFloor = 20001;
const FatalErrorCeiling = 20099;

const restAPI = '/dbTwig/reactExample/';

export function buildURL(path, parameters)
{
  let apiURL = (window.dbTwigHost !== null ? 
    window.dbTwigHost + restAPI : 
    window.location.protocol + '//' + window.location.hostname  + 
      (80 !== window.location.port || 443 !== window.location.port ? ':' + window.location.port : '') + restAPI);

  if (typeof parameters === 'undefined')
    return apiURL + path;
  else
    return apiURL + path + parameters;
}

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
      window.openAppModal(errorMessage, result.errorMessage, true);
      return;
  }
}

export async function callRestAPI(entryPoint, bodyData)
{
  let headers = { 'Content-Type': 'application/json'};
//  if (null !== window.userSession.getSessionId()) headers.Authorization = 'Bearer ' + window.userSession.getSessionId();

  var request;

  request = (undefined === bodyData ? 
    new Request(buildURL(entryPoint), {headers: new Headers(headers)}) :
    new Request(buildURL(entryPoint), {method: "POST", body: JSON.stringify(bodyData), headers: new Headers(headers)}));

  let response = await fetch(request).catch(function(error)
  {
    return {status: 'httpError', errorMessage: 'Lost connection to server - ' + error};
  });

  var errorMsg = "Server response not understood.  Consult the system & framework error logs for further information.";

  if ('httpError' === response.status) return response;

  if (!response.ok)
  {
    if (response.headers.has('Content-Type') && response.headers.get('Content-Type') === 'application/json; charset=utf-8')
    {
      let jsonData = await response.json();

      if (typeof jsonData.errorCode === 'undefined') return {status: 'fatalError'};

      if (jsonData.errorCode >= FatalErrorFloor && jsonData.errorCode <= FatalErrorCeiling)
        return {status: 'fatalError'};
      else
        return {status: 'apiError', ...jsonData};
    }
    else
      return {status: 'httpError', errorMessage: errorMsg}
  }     

  if (response.ok)
  {
    if (response.headers.has('Content-Type') && response.headers.get('Content-Type') === 'application/json; charset=utf-8')
    {
      let jsonData = await response.json();
      return {status: 'success', jsonData: jsonData};
    }
    else
      return {status: 'jsonFailure', errorMessage: 'Invalid content type: ' + response.headers.get('Content-Type')};
  }
}
