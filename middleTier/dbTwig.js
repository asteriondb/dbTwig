const oracledb = require('oracledb');
oracledb.autoCommit = true;

const ORA_PACKAGE_STATE_DISCARDED = 4068;
const FATAL_API_ERROR_FLOOR = 20000;
const SESSION_TIMEOUT = 20002;
const USER_PASSWORD_ERROR = 20124;
const USER_PASSWORD_ERROR_MSG = 'The username or password is invalid';
const CREATE_USER_SESSION = 'createUserSession';

var systemParameters = 
{
  authorization: null,
  clientAddress: null,
  serverAddress: null,
  userAgent: null,
  httpHost: null,
  debugMode: (undefined === process.env.DEBUG_DBTWIG ? 'N' : 'Y')
};

var errorHandler = async function(connection, url, error, sqlText)
{
  let errorParameters =
  {
    errorCode: error.errorNum,
    errorMessage: error.message,
    errorOffset: error.offset,
    sqlText: sqlText,
    scriptFilename: __filename,
    functionName: 'callDbTwig',
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
      console.error(logError);
      console.error('Attempted to log this error object:');
      console.error({...systemParameters, ...errorParameters});

      return {status: false, errorCode: errorParameters.errorCode, errorMessage: errorParameters.errorMessage};
    }

    return {status: false, lob: result.outBinds.jsonData};
  }
  else
    return {status: false, errorCode: error.errorNum, errorMessage: error.errorMessage};
}

var msleep = function(microSeconds) 
{
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, microSeconds);
}

exports.getConnectionFromPool = async function()
{
  return await oracledb.getPool().getConnection()
}

exports.callDbTwig = async function(server, connection, request)
{
  systemParameters.authorization = request.get('Authorization');
  systemParameters.clientAddress = request.ip;
  systemParameters.userAgent = request.get('User-Agent');
  systemParameters.httpHost =  request.get('Host');
  systemParameters.serverAddress = server.address().address;

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
      return {status: false, errorCode: oraError, errorMessage: USER_PASSWORD_ERROR_MSG};
    }
    
    if (ORA_PACKAGE_STATE_DISCARDED !== oraError)
    {
      let obj = await errorHandler(connection, request.originalUrl, error, text);
      return obj;
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
      let obj = await errorHandler(connection, request.originalUrl, error, text);
      return obj;
    }
  }

  return {status: true, lob: result.outBinds.jsonData};
}

exports.sendLobResponse = async function(lob, response)
{
  const doStream = new Promise((resolve, reject) => 
  {
    lob.on('end', () => 
    {
      response.end();
    });
    lob.on('close', () => 
    {
      resolve();
    });
    lob.on('error', (err) => 
    {
      reject(err);
    });
    
    lob.pipe(response);
  });

  try
  {
    await doStream;  
  }
  catch (error)
  {
    console.log(error);
  }
}

exports.getJsonPayload = async function(lob)
{
  let jsonPayload = '';

  const doStream = new Promise((resolve, reject) => 
  {    
    lob.setEncoding('utf8');  // set the encoding so we get a 'string' not a 'buffer'
    lob.on('error', function(err) 
    { 
      status = 500;
      console.log(err); 
      reject();
    });
  
    lob.on('data', function(chunk) 
    {
      jsonPayload += chunk;
    });
  
    lob.on('end', function() 
    {
      resolve();
    });    
  });
  
  try
  {
    await doStream;  
    return jsonPayload;
  }
  catch (error)
  {
    console.log(error);
  }
}

exports.init = async function()
{
  let credentials = 
  {
    user: process.env.DBTWIG_USER, 
    password: process.env.DBTWIG_PASSWORD, 
    connectString: process.env.DB_NAME
  };

  try
  {
    await oracledb.createPool(credentials);
    return true
  }
  catch (error)
  {
    console.error(error);
    return false;
  }
}

exports.closePool = async function()
{
  console.log('Closing oracle connection pool....');
  try
  {
    await oracledb.getPool().close(10);
  }
  catch (error)
  {
    console.error(error);
  }
}

exports.closeConnection = async function(connection)
{
  if (null !== connection) await connection.close();
}