const express = require('express');
var app = express();

const port = 3030
const oracledb = require('oracledb');
oracledb.autoCommit = true;

const ORA_PACKAGE_STATE_DISCARDED = 4068;
const FATAL_API_ERROR_FLOOR = 20000;
const SESSION_TIMEOUT = 20002;
const FATAL_API_ERROR_CEILING = 20099;
const NON_FATAL_API_ERROR_FLOOR = 20100;
const USER_PASSWORD_ERROR = 20124;
const USER_PASSWORD_ERROR_MSG = 'The username or password is invalid';
const MAX_ROWS_FETCHED = 10000;
const CREATE_USER_SESSION = 'createUserSession';

app.use(express.json());

app.use(function(req, res, next) 
{
  res.header("Access-Control-Allow-Origin", req.get('Origin')); 
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization");
  res.contentType("application/json");
  next();
});

app.get('/objVaultAPI/:entryPoint', handleRequest);
app.post('/objVaultAPI/:entryPoint', handleRequest);

var connection = null;

var systemParameters = 
{
  authorization: null,
  clientAddress: null,
  serverAddress: null,
  userAgent: null,
  httpHost: null,
  debugMode: (undefined === process.env.DEBUG_DBTWIG ? 'N' : 'Y')
};

async function errorHandler(response, url, error, sqlText, caller)
{
  let errorParameters =
  {
    errorCode: error.errorNum,
    errorMessage: error.message,
    errorOffset: error.offset,
    sqlText: sqlText,
    scriptFilename: __filename,
    functionName: caller,
    requestUri: url
  };

  if (SESSION_TIMEOUT != error.errorNum)
  {
    let text = 'begin :jsonData := db_twig.rest_api_error(:jsonParameters); end;';
    let bindVars = 
    {
      jsonData: {type: oracledb.CLOB, dir: oracledb.BIND_OUT},
      jsonParameters: JSON.stringify({...systemParameters, ...errorParameters})
    }

    let result = null;
    try
    {
      result = await connection.execute(text, bindVars);
    }
    catch (logError)
    {
      console.error('Unable to log a RestAPI error to the database.');
      console.error('Log attempt returned Oracle error code: ' + logError.errorNum);
      console.error(logError.message);
      console.error('Attempted to log this error object:');
      console.error({...systemParameters, ...errorParameters});

      return {errorCode: FATAL_API_ERROR_FLOOR, errorMessage: 'An unexpected error has occurred.  Consult the system and framework error logs.'};
    }

    let lob = result.outBinds.jsonData;

    const doStream = new Promise((resolve, reject) => 
    {
      lob.on('end', () => 
      {
        // console.log("lob.on 'end' event");
        response.end();
      });
      lob.on('close', () => 
      {
        // console.log("lob.on 'close' event");
        resolve();
      });
      lob.on('error', (err) => 
      {
        // console.log("lob.on 'error' event");
        reject(err);
      });
      
      lob.pipe(response.status(500));  // write the image out
    });
  
    await doStream;
  }
  else
    response.status(500).send({errorCode: error.errorNum, errorMessage: error.errorMessage});
}

function msleep(microSeconds) 
{
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, microSeconds);
}

async function handleRequest(request, response)
{
  systemParameters.authorization = request.get('Authorization');
  systemParameters.clientAddress = request.ip;
  systemParameters.userAgent = request.get('User-Agent');
  systemParameters.httpHost =  request.get('Host');
  systemParameters.serverAddress = server.address().address;

  connection = await oracledb.getPool().getConnection()
  let text = 'begin :jsonData := db_twig.call_rest_api(:jsonParameters); end;';
  let bindVars = 
  {
    jsonData: {type: oracledb.CLOB, dir: oracledb.BIND_OUT},
    jsonParameters: JSON.stringify({...systemParameters, ...request.body, entryPoint: request.params.entryPoint})
  }

  let oraError = 0;
  let result = null;

  try
  {
    result = await connection.execute(text, bindVars);
  }
  catch (error)
  {
    oraError = error.errorNum;
    
    if (USER_PASSWORD_ERROR === oraError && CREATE_USER_SESSION === request.params.entryPoint)
    {
      msleep(5000);
      response.status(500).send({errorCode: oraError, errorMessage: USER_PASSWORD_ERROR_MSG});
      return;
    }
    
    if (ORA_PACKAGE_STATE_DISCARDED !== oraError)
    {
      await errorHandler(response, request.originalUrl, error, text, arguments.callee.name);
      await connection.close();
//      response.set('Content-Type', 'application/json');
      return;
    }
  }

  if (ORA_PACKAGE_STATE_DISCARDED === oraError)
  {
    try
    {
      const result = await connection.execute(text, bindVars);
    }
    catch (error)
    {
      await errorHandler(response, request.originalUrl, error, text, arguments.callee.name);
      await connection.close();
      return;
    }
  }

  let lob = result.outBinds.jsonData;

  const doStream = new Promise((resolve, reject) => 
  {
    lob.on('end', () => 
    {
      // console.log("lob.on 'end' event");
      response.end();
    });
    lob.on('close', () => 
    {
      // console.log("lob.on 'close' event");
      resolve();
    });
    lob.on('error', (err) => 
    {
      // console.log("lob.on 'error' event");
      reject(err);
    });
    
    lob.pipe(response);  // write the image out
  });

  await doStream;
  await connection.close();
}

async function oracleInit()
{
  let credentials = {user: 'objvault_dev', password: 'objvault_dev', connectString: 'local-dev'};
  try
  {
    await oracledb.createPool(credentials);
  }
  catch (error)
  {
    console.error(error);
  }
}

async function closePoolAndExit()
{
  console.log('Exiting....');
  try
  {
    await oracledb.getPool().close(10);
    console.log('Oracle connection pool closed...');
    process.exit(1);
  }
  catch (error)
  {
    console.error(error);
    process.exit(1);
  }
}

process
  .once('SIGTERM', closePoolAndExit)
  .once('SIGINT', closePoolAndExit);

oracleInit();

console.log('DbTwig Middle-Tier Server listening on port: ' + port);
let server = app.listen(port);
