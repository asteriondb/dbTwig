const express = require('express');
var app = express();

const axios = require('axios').default;

var Busboy = require('busboy');

const port = 3030

const dbTwig = require('./dbTwig');

const MIDDLE_TIER_VERSION = '0.0.1';
const HTTP_SERVER_ERROR = 500;

app.use(express.json());

app.use(function(req, res, next) 
{
  res.header("Access-Control-Allow-Origin", req.get('Origin')); 
  res.header("Access-Control-Allow-Headers", "Cache-Control, Origin, X-Requested-With, Content-Type, Accept, Authorization");
  res.contentType("application/json");
  next();
});

app.get('/objVaultAPI/tutorials/:entryPoint', handleTutorialsRequest);
app.post('/objVaultAPI/tutorials/:entryPoint', handleTutorialsRequest);

app.post('/objVaultAPI/uploadFiles', handleUploadRequest);

app.get('/objVaultAPI/getSupportInfo', getSupportInfoRequest);

app.get('/ObjVaultAPI/oauthReply', handleOauthReply);

app.get('/objVaultAPI/:entryPoint', handleRequest);
app.post('/objVaultAPI/:entryPoint', handleRequest);

var os = require('os'), fs = require('fs');

function getRequestData(request)
{
  return(
  {
    authorization: request.get('Authorization'), 
    clientAddress: request.ip,
    userAgent: request.get('User-Agent'),
    httpHost: request.get('Host'),
    body: request.body,
    entryPoint: request.params.entryPoint,
    originalUrl: request.originalUrl
  });
}

async function handleOauthReply(request, response)
{
  var state = request.query.state;
  var origin = state.substr(0, state.lastIndexOf('/'));
  var sessionId = state.substr(state.lastIndexOf('/') + 1);

  let requestData = 
  {
    authorization: request.get('Authorization'), 
    clientAddress: request.ip,
    userAgent: request.get('User-Agent'),
    httpHost: request.get('Host'),
    body: request.body,
    entryPoint: 'saveOauthReply',
    originalUrl: request.originalUrl
  };

  if (undefined !== request.query.error || undefined === request.query.code)
  {
    let connection = await dbTwig.getConnectionFromPool();
    let result = await dbTwig.callDbTwig(server, connection, requestData);
  
    if (!result.status) response.status(HTTP_SERVER_ERROR);

    if (undefined !== result.lob)
    {
      let jsonPayload = await dbTwig.getJsonPayload(result.lob);
      response.redirect(origin + '/gmailAuthReply');
    }
    else
      response.redirect(origin + '/gmailAuthReply');
  
    dbTwig.closeConnection(connection);
  }

  requestData.entryPoint = 'getGmailAccessTokenParams';
  requestData.authorization = 'Bearer ' + sessionId;
  requestData.body = {authorizationCode: request.query.code};

  let connection = await dbTwig.getConnectionFromPool();
  let result = await dbTwig.callDbTwig(server, connection, requestData);
  
  var jsonPayload;

  if (undefined !== result.lob)
    jsonPayload = await dbTwig.getJsonPayload(result.lob);
  else
    jsonPayload = JSON.stringify({errorCode: result.errorCode, errorMessage: result.errorMessage});

  if (!result.status)
  {
    dbTwig.closeConnection(connection);
    return response.status(HTTP_SERVER_ERROR).send(jsonPayload);
  } 

  let jsonObject = JSON.parse(jsonPayload);
  let axiosArgs = 
  { 
    method: 'post', 
    url: jsonObject.getAccessTokenUrl, 
    params: new URLSearchParams(jsonObject.getAccessTokenData)
  };

  try
  {
    let response = await axios(axiosArgs);
    requestData.body = response.data;
  }
  catch (error)
  {
    requestData.body = error.response.data;
  }

  requestData.entryPoint = 'saveOauthReply';

  result = await dbTwig.callDbTwig(server, connection, requestData);

  if (undefined !== result.lob)
    jsonPayload = await dbTwig.getJsonPayload(result.lob);
  else
    jsonPayload = JSON.stringify({errorCode: result.errorCode, errorMessage: result.errorMessage});

  dbTwig.closeConnection(connection);
  response.redirect(origin + '/gmailAuthReply');
}

async function handleUploadRequest(request, response)
{
  let fileId = null;

  let jsonParms = {gatewayName: os.hostname()};

  var busBoy = new Busboy({ headers: request.headers });

  busBoy.on('field', function(fieldname, val, fieldnameTruncated, valTruncated)
  {
    switch (fieldname)
    {
      case 'qquuid':
        fileId = val;
        break;

      case 'qqfilename':
        jsonParms.sourcePath =val;
        break;

      case 'qqtotalfilesize':
        jsonParms.filesize = val;
        break;

      case 'objectId':
        jsonParms.objectId = val;
        break;

      case 'newVersion':
        jsonParms.newVersion = val;
        break;

      case 'creation_date':
        jsonParms.creationDate = val;
        break;

      case 'modification_date':
        jsonParms.modificationDate = val;
        break;

      case 'access_date':
        jsonParms.accessDate = val;
        break;

      default:
        console.log(fieldname);
        console.log(val);
        break;
    }
  });

  var status;
  var jsonPayload;

  busBoy.on('file', async function(fieldname, file, filename, encoding, mimetype) 
  {
    request.body = jsonParms;
    request.params.entryPoint = 'createUploadedFile';

    let connection = await dbTwig.getConnectionFromPool();
    let result = await dbTwig.callDbTwig(server, connection, getRequestData(request));

    status = result.status;

    if (undefined !== result.lob)
      jsonPayload = await dbTwig.getJsonPayload(result.lob);
    else
      jsonPayload = JSON.stringify({errorCode: result.errorCode, errorMessage: result.errorMessage});

    if (status)
    {
      let jsonObject = JSON.parse(jsonPayload);
      file.pipe(fs.createWriteStream(jsonObject.filename));
    }
    else
    {
      response.status(HTTP_SERVER_ERROR);
      file.resume();
    }
      
    dbTwig.closeConnection(connection);
  });

  busBoy.on('finish', function() 
  {
    let jsonResponse = {uuid: fileId, success: status ? 1 : 0};

    if (!status) jsonResponse = {...jsonResponse, ...JSON.parse(jsonPayload)};
    
    response.send(JSON.stringify(jsonResponse));
  });

  return request.pipe(busBoy);
}

async function getSupportInfoRequest(request, response)
{
  request.params.entryPoint = 'getSupportInfo';
  let connection = await dbTwig.getConnectionFromPool();
  let result = await dbTwig.callDbTwig(server, connection, getRequestData(request));

  var jsonPayload;
  if (undefined !== result.lob)
    jsonPayload = await dbTwig.getJsonPayload(result.lob);
  else
    jsonPayload = JSON.stringify({errorCode: result.errorCode, errorMessage: result.errorMessage});

  if (result.status)
  {
    let jsonObject = JSON.parse(jsonPayload);

    jsonObject.databaseVersion = dbTwig.oracleServerVersionString(connection);
    jsonObject.databaseClientVersion = dbTwig.oracleClientVersionString;
    jsonObject.middleTierVersion = MIDDLE_TIER_VERSION;
    
    jsonPayload = JSON.stringify(jsonObject);
  }
  else
    response.status(HTTP_SERVER_ERROR);


  dbTwig.closeConnection(connection);
  return response.send(jsonPayload);
}

async function handleRequest(request, response)
{
  let connection = await dbTwig.getConnectionFromPool();

  let result = await dbTwig.callDbTwig(server, connection, getRequestData(request));

  if (!result.status) response.status(HTTP_SERVER_ERROR);
  if (undefined !== result.lob)
    await dbTwig.sendLobResponse(result.lob, response);
  else
    response.send({errorCode: result.errorCode, errorMessage: result.errorMessage});

  dbTwig.closeConnection(connection);
}

async function handleTutorialsRequest(request, response)
{
  let entryPoint = 'tutorials/' + request.params.entryPoint;
  request.params.entryPoint = entryPoint;
  let connection = await dbTwig.getConnectionFromPool();
  let result = await dbTwig.callDbTwig(server, connection, getRequestData(request));

  if (!result.status) response.status(HTTP_SERVER_ERROR);

  if (undefined !== result.lob)
    await dbTwig.sendLobResponse(result.lob, response);
  else
    response.send({errorCode: result.errorCode, errorMessage: result.errorMessage});

  dbTwig.closeConnection(connection);
}

async function closePoolAndExit()
{
  dbTwig.closePool();
  process.exit(0);
}

process
  .once('SIGTERM', closePoolAndExit)
  .once('SIGINT', closePoolAndExit);

if (!dbTwig.init()) process.exit(1);

console.log('DbTwig Middle-Tier Server listening on port: ' + port);
let server = app.listen(port, "127.0.0.1");