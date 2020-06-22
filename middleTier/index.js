const express = require('express');
var app = express();

var Busboy = require('busboy');

const port = 3030

const dbTwig = require('./dbTwig');

const tutorials = require('./tutorials');

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

app.get('/objVaultAPI/:entryPoint', handleRequest);
app.post('/objVaultAPI/:entryPoint', handleRequest);

var os = require('os'), fs = require('fs');

async function handleUploadRequest(request, response)
{
  let fileId = null;

  let jsonParms = {gatewayName: os.hostname()};
  let jsonString = '';
  let status = 200;

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

  busBoy.on('file', async function(fieldname, file, filename, encoding, mimetype) 
  {
    request.body = jsonParms;
    request.params.entryPoint = 'createUploadedFile';

    let connection = await dbTwig.getConnectionFromPool();
    let result = await dbTwig.callDbTwig(server, connection, request);

    var jsonPayload;

    if (!result.status) status = 500;

    if (undefined !== result.lob)
    {
      jsonPayload = await dbTwig.getJsonPayload(result.lob);
      
      if (200 === status)
      {
        let jsonObject = JSON.parse(jsonPayload);
        file.pipe(fs.createWriteStream(jsonObject.filename));
      }
      else
      {
        file.resume();
      }
    }
    else
    {
      jsonPayload = JSON.stringify({errorCode: result.errorCode, errorMessage: result.errorMessage});
      file.resume();
    }
      
    dbTwig.closeConnection(connection);
  });

  busBoy.on('finish', function() 
  {
    let jsonResponse = {uuid: fileId, success: 500 === status ? 0 : 1};

    if (500 === status)
    {
      let error = JSON.parse(jsonPayload);
      jsonResponse = {...jsonResponse, ...error};
    }
    response.status(status).send(JSON.stringify(jsonResponse));
  });

  return request.pipe(busBoy);
}

async function handleRequest(request, response)
{
  let connection = await dbTwig.getConnectionFromPool();
  let result = await dbTwig.callDbTwig(server, connection, request);

  if (!result.status) response.status(500);
  if (undefined !== result.lob)
    await dbTwig.sendLobResponse(result.lob, response);
  else
    response.send({errorCode: result.errorCode, errorMessage: result.errorMessage});

  dbTwig.closeConnection(connection);
}

function handleTutorialsRequest(request, response)
{
  tutorials.handleTutorialsRequest(server, request, response);
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
let server = app.listen(port);