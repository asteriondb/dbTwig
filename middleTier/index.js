/******************************************************************************
 *                                                                            *
 *  Copyright (c) 2018, 2022 by AsterionDB Inc.                               *
 *                                                                            *
 *  All rights reserved.  No part of this work may be reproduced or otherwise *
 *  incorporated into other works without the express written consent of      *
 *  AsterionDB Inc.                                                           *
 *                                                                            *
 *****************************************************************************/

const express = require('express');
var app = express();

const axios = require('axios').default;

const busboyP = require('busboy');

const port = (undefined === process.env.DBTWIG_PORT ? 3030 : process.env.DBTWIG_PORT);

const {format, createLogger, transports} = require('winston');

let errorLog = process.env.HOME + '/asterion/oracle/logs/db-twig-error.log';
let combinedLog = process.env.HOME + '/asterion/oracle/logs/db-twig-combined.log';

const logger = createLogger(
{
  level: 'info',
  format: format.combine(
    format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    format.errors({ stack: true }),
    format.splat(),
    format.json()
  ),
  defaultMeta: { service: 'dbTwig' },
  transports: [
    //
    // - Write to all logs with level `info` and below to `quick-start-combined.log`.
    // - Write all logs error (and below) to `quick-start-error.log`.
    //
    new transports.File({ filename: errorLog, level: 'error' }),
    new transports.File({ filename: combinedLog })
  ]
});

exports.logger = logger;

//
// If we're not in production then **ALSO** log to the `console`
// with the colorized simple format.
//
if (process.env.NODE_ENV !== 'production') 
{
  logger.add(new transports.Console(
  {
    format: format.combine
    (
      format.colorize(),
      format.simple()
    )
  }));
}

const dbTwig = require('dbTwig');

const HTTP_SERVER_ERROR = 500;

app.use(express.json());

app.use(function(req, res, next) 
{
  res.header("Access-Control-Allow-Origin", req.get('Origin')); 
  res.header("Access-Control-Allow-Headers", "Cache-Control, Origin, X-Requested-With, Content-Type, Accept, Authorization");
  res.contentType("application/json");
  next();
});

app.post('/dbTwig/:serviceName/uploadFiles', handleUploadRequest);

app.get('/dbTwig/:serviceName/getSupportInfo', getSupportInfoRequest);

app.get('/dbTwig/:serviceName/oauthReply', handleOauthReply);

app.get('/dbTwig/:serviceName/:entryPoint', handleRequest);
app.post('/dbTwig/:serviceName/:entryPoint', handleRequest);

app.get('/dbTwig/:serviceName/:entryPoint/*', handleRequest);
app.post('/dbTwig/:serviceName/:entryPoint/*', handleRequest);

app.get('/dbTwig/:serviceName', handleRequest);

var os = require('os'), fs = require('fs');

var msleep = function(microSeconds) 
{
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, microSeconds);
}

function getRequestData(request, serverAddress)
{
  let authorization = request.get('authorization');

  return(
  {
    sessionId: (undefined !== authorization ? authorization.split(" ")[1] : ""), 
    clientAddress: request.headers['x-real-ip'] ? request.headers['x-real-ip'] : request.headers['x-forwarded-for'],
    userAgent: request.get('User-Agent'),
    httpHost: request.get('Host'),
    body: request.body,
    query: request.query,
    serviceName: request.params.serviceName,
    entryPoint: undefined === request.params.entryPoint ? '/' : request.params.entryPoint,
    originalUrl: request.originalUrl,
    serverAddress: serverAddress
  });
}

async function handleOauthReply(request, response)
{
  var state = request.query.state;
  var origin = state.substr(0, state.lastIndexOf('/'));
  var sessionId = state.substr(state.lastIndexOf('/') + 1);

  let authorization = request.get('authorization');

  let requestData = 
  {
    sessionId: (undefined !== authorization ? authorization.split(" ")[1] : ""), 
    clientAddress: request.headers['x-forwarded-for'],
    userAgent: request.get('User-Agent'),
    httpHost: request.get('Host'),
    body: request.body,
    entryPoint: 'saveOauthReply',
    serviceName: 'asterionDB',
    originalUrl: request.originalUrl,
    serverAddress: server.address().address
  };

  if (undefined !== request.query.error || undefined === request.query.code)
  {
    let connection = await dbTwig.getConnectionFromPool();
    let result = await dbTwig.callDbTwig(connection, requestData);
  
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
  requestData.sessionId = sessionId;
  requestData.body = {authorizationCode: request.query.code};

  let connection = await dbTwig.getConnectionFromPool();
  let result = await dbTwig.callDbTwig(connection, requestData);
  
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

  result = await dbTwig.callDbTwig(connection, requestData);

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

  const busBoy = busboyP({ headers: request.headers });

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
        break;
    }
  });

  var status;
  var jsonPayload;
  var result;

  busBoy.on('file', async function(fieldname, file, filename, encoding, mimetype) 
  {
    request.body = jsonParms;
    request.params.entryPoint = 'createUploadedObject';

    let connection = await dbTwig.getConnectionFromPool();
    result = await dbTwig.callDbTwig(connection, getRequestData(request, server.address().address));

    status = result.status;

    if (undefined !== result.lob)
      jsonPayload = await dbTwig.getJsonPayload(result.lob);
    else
//      jsonPayload = JSON.stringify({errorCode: result.errorCode, errorMessage: result.errorMessage});
      response.send(JSON.stringify({errorCode: result.errorCode, errorMessage: result.errorMessage}));

    if (status)
    {
      let jsonObject = JSON.parse(jsonPayload);
      result = file.pipe(fs.createWriteStream(jsonObject.filename))
        .on('error', function(e)
        {
          let jsonResponse = {uuid: fileId, success: 0, errorMessage: e.message.substring(0, e.message.indexOf(','))};
          response.send(JSON.stringify(jsonResponse));
        })
        .on('close', function(x)
        {
          let jsonResponse = {uuid: fileId, success: 1};
          response.send(JSON.stringify(jsonResponse));
        });
    }
    else
    {
      response.status(HTTP_SERVER_ERROR);
      file.resume();
    }
      
    dbTwig.closeConnection(connection);
  });

  return request.pipe(busBoy);
}

async function getSupportInfoRequest(request, response)
{
  request.params.entryPoint = 'getSupportInfo';
  let connection = await dbTwig.getConnectionFromPool();
  let result = await dbTwig.callDbTwig(connection, getRequestData(request, server.address().address));

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
    jsonObject.dbTwigListener = require('./package.json').gitTag + '-' + require('./package.json').gitBranch;
    
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

  let result = await dbTwig.callDbTwig(connection, getRequestData(request, server.address().address));

  if (!result.status) response.status(HTTP_SERVER_ERROR);
  if (undefined !== result.lob && null !== result.lob)
    await dbTwig.sendLobResponse(result.lob, response);
  else
  {
    response.send({errorCode: result.errorCode, errorMessage: result.errorMessage});
  }

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


logger.log('info', 'DbTwig Middle-Tier Server listening on port: %d', port);
console.log('DbTwig Middle-Tier Server listening on port: ' + port);
let server = app.listen(port, "127.0.0.1");
