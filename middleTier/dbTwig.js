/******************************************************************************
 *                                                                            *
 *  Copyright (c) 2018, 2022 by AsterionDB Inc.                               *
 *                                                                            *
 *  All rights reserved.  No part of this work may be reproduced or otherwise *
 *  incorporated into other works without the express written consent of      *
 *  AsterionDB Inc.                                                           *
 *                                                                            *
 *****************************************************************************/

const {logger} = require('./index');

const oracledb = require('oracledb');
oracledb.autoCommit = true;

const ORA_PACKAGE_STATE_DISCARDED = 4068;

const USER_PASSWORD_ERROR = 20124;
const USER_PASSWORD_ERROR_MSG = 'The username or password is invalid';
const ACCOUNT_LOCKED = 20125;
exports.SESSION_TIMEOUT = 20002;

var systemParameters = 
{
  sessionId: null,
  clientAddress: null,
  serverAddress: null,
  userAgent: null,
  httpHost: null
};

var msleep = function(microSeconds) 
{
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, microSeconds);
}

exports.getConnectionFromPool = async function()
{
  return await oracledb.getPool().getConnection()
}

var tryAndCatch = async function(connection, text, bindVars)
{
  let result = null;

  try
  {
    result = await connection.execute(text, bindVars);
  }
  catch (error)
  {
    return {status: false, error: error};
  }

  return {status: true, lob: result.outBinds.jsonData};
}

exports.callDbTwig = async function(connection, requestData)
{
  //  Need logic here to throw an error if the client tries to stuff our system parameters in the bodyData.
  
  systemParameters.sessionId = requestData.sessionId;
  systemParameters.clientAddress = requestData.clientAddress;
  systemParameters.userAgent = requestData.userAgent;
  systemParameters.httpHost =  requestData.httpHost;
  systemParameters.serverAddress = requestData.serverAddress;

  let text = 'declare json_data clob := null; begin json_data := call_restapi(:jsonParameters); :jsonData := json_data; end;';
  let bindVars = 
  {
    jsonData: {type: oracledb.CLOB, dir: oracledb.BIND_OUT},
    jsonParameters: JSON.stringify({...systemParameters, ...requestData.body, ...requestData.query, serviceName: requestData.serviceName, 
      entryPoint: requestData.entryPoint})
  }

  let result = await tryAndCatch(connection, text, bindVars);

  if (result.status) return result;

  if (ORA_PACKAGE_STATE_DISCARDED === result.error.errorNum)
  {
    result = await tryAndCatch(connection, text, bindVars);
    if (result.status) return result;
  }

  if (USER_PASSWORD_ERROR === result.error.errorNum)
  {
    msleep(5000);
    return {status: false, errorCode: result.error.errorNum, errorMessage: USER_PASSWORD_ERROR_MSG};
  }
  
  if (ACCOUNT_LOCKED === result.error.errorNum)
  {
    msleep(5000);
    return {status: false, errorCode: result.error.errorNum, errorMessage: result.error.message};
  }
  
  return {status: false, errorCode: result.error.errorNum, errorMessage: result.error.message};
}

exports.oracleClientVersionString = oracledb.versionString;
exports.oracleServerVersionString = function(connection)
{
  return connection.oracleServerVersionString;
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
    logger.log('error', error);
    console.error(error);
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
      logger.log('error', err); 
      console.error(err); 
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
  catch (err)
  {
    logger.log('error', err); 
    console.error(err); 
  }
}

exports.init = async function()
{
  let credentials = 
  {
    user: process.env.DBTWIG_USER, 
    password: process.env.DBTWIG_PASSWORD, 
    connectString: process.env.DATABASE_NAME
  };

  try
  {
    await oracledb.createPool(credentials);
    return true
  }
  catch (err)
  {
    logger.log('error', err); 
    console.error(err); 
    return false;
  }
}

exports.closePool = async function()
{
  try
  {
    await oracledb.getPool().close(10);
  }
  catch (err)
  {
    logger.log('error', err); 
    console.error(err); 
  }
}

exports.closeConnection = async function(connection)
{
  if (null !== connection) await connection.close();
}