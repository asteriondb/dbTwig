// const requestHandlers = require('./requestHandlers');

var dbTwig = require('./dbTwig');

exports.handleTutorialsRequest = async function(server, request, response)
{
  let entryPoint = 'tutorials/' + request.params.entryPoint;
  request.params.entryPoint = entryPoint;
  let connection = await dbTwig.getConnectionFromPool();
  let result = await dbTwig.callDbTwig(server, connection, request);

  if (!result.status) response.status(500);

  if (undefined !== result.lob)
    await dbTwig.sendLobResponse(result.lob, response);
  else
    response.send({errorCode: result.errorCode, errorMessage: result.errorMessage});

  dbTwig.closeConnection(connection);
}