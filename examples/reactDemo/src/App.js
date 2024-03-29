import React from 'react';
import './css/app.css';

import { Card, CardBody, CardFooter } from 'reactstrap'

import ReactExample from './ReactExample';

function App() {
  var versionNumber = 'tag: ' + require('../package.json').gitTag + ' branch: ' + require('../package.json').gitBranch;

  return (
    <div>
      <Card>
        <CardBody>
          <ReactExample></ReactExample>
        </CardBody>
        <CardFooter>ReactDemo version: {versionNumber} Copyright &copy; {new Date().getFullYear()} by AsterionDB Inc. All Rights Reserved</CardFooter>
      </Card>
    </div>    
  );
}

export default App;
