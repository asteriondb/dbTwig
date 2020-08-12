import React from 'react';
import './css/app.css';

import { Card, CardBody, CardFooter } from 'reactstrap'

import ReactExample from './ReactExample';

function App() {
  var versionNumber = require('../package.json').version

  return (
    <div>
      <Card>
        <CardBody>
          <ReactExample></ReactExample>
        </CardBody>
        <CardFooter>ReactExample version: {versionNumber} Copyright &copy; AsterionDB Inc. All Rights Reserved</CardFooter>
      </Card>
    </div>    
  );
}

export default App;
