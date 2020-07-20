exports.buildURL = function(path, parameters)
{
  let dbTwigHost = 'http://jjflash.asteriondb.local'; // null;
  let tutorialsService = '/dbTwig/asterionDBTutorials';

  let dbTwigListener = (dbTwigHost !== null ? dbTwigHost + tutorialsService : window.location.protocol + '//' + window.location.hostname  + 
    (80 !== window.location.port || 443 !== window.location.port ? ':' + window.location.port : '') + tutorialsService);

   if (typeof parameters === 'undefined')
     return dbTwigListener + path;
   else
     return dbTwigListener + path + parameters;
}

/**
  * Generic API fetch request and response/error handling
  * By: Paul Lesniewski & Steve Guilford
  *
  * @param object request Request object defining API request
  * @param function goodResponseHandler Function that will be called
  *                                     upon success with good
  *                                     response (will be provided
  *                                     response and JSON args as
  *                                     well as the "extra" parameter
  *                                     value)
  * @param function badResponseHandler Function that will be called
  *                                    upon all non-fatal non-ok
  *                                    responses, (including non-200
  *                                    responses such as 404 which
  *                                    have been served directly from
  *                                    the web server and that the API
  *                                    never sees) (will be provided
  *                                    response and JSON args as well
  *                                    as the "extra" parameter value)
  * @param function errorHandler Function that will be called upon (fatal)
  *                              error (currently only caused by lost
  *                              connection) (will be given error message
  *                              argument as well as the "extra" parameter
  *                              value)
  * @param mixed extra Any extra data that the caller needs to convey
  *                    to the result handler functions
  * @param boolean logoutErrorIsNonCritical When given as boolean true,
  *                                         indicates that errors handled
  *                                         by logoutBadResponse() (see
  *                                         below) should NOT cause a
  *                                         logout and redirect
  *
  */
exports.callDbTwig = async function(request, goodResponseHandler, badResponseHandler, errorHandler, extra, logoutErrorIsNonCritical)
{
  if (undefined !== request.body)
  {
    let body = await request.body.blob();
    console.log(body);
  }

  let requestX = request;
  let newHeader = new Headers({ 'Content-Type': 'application/json'});
  requestX = new Request(request, { headers: newHeader});

  fetch(requestX).then(function(response)
  {
    fetchComplete(response, goodResponseHandler, badResponseHandler, extra, logoutErrorIsNonCritical, request);
  }).catch(function(error)
  {
    console.log('Fatal error:', error);
    console.log('Faulty request:', request);
    errorHandler('Error: Lost connection to server', extra);
  });
}

/**
  * DO NOT CALL DIRECTLY; Only intended for use with window.apiRequest - see above
  */
var fetchComplete = function(response, goodResponseHandler, badResponseHandler, extra, logoutErrorIsNonCritical, request)
{
  if (!response.ok)
  {
    if (response.headers.has('Content-Type') && response.headers.get('Content-Type') === 'application/json; charset=utf-8')
    {
      return response.json().then(function(jsonData)
      {
        badResponseHandler(response, jsonData, extra);
      });
    }
    else
    {
      badResponseHandler(response, { code: response.status, errorMessage: "Server response not understood.  Consult the system & framework error logs for further information." }, extra);
    }
  }     
 
  if (response.ok)
  {
    if (response.headers.has('Content-Type') && response.headers.get('Content-Type') === 'application/json; charset=utf-8')
    {
      return response.json().then(function(jsonData)
      {
        goodResponseHandler(response, jsonData, extra);
      });   
    }
    else
    {
      return response.text().then(function(text)
      {
        goodResponseHandler(response, text, extra);
      });
    }
  }
}

exports.debounce = function(func, wait, immediate)
{
//TODO: change "var" to "let" where possible herein
  var timeout;
  return function()
  {
    var context = this, args = arguments;
    var later = function()
    {
      timeout = null;
      if (!immediate) func.apply(context, args);
    };
    var callNow = immediate && !timeout;
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
    if (callNow) func.apply(context, args);
  };
}
