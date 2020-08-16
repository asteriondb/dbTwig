/******************************************************************************
 *                                                                            *
 *  Copyright (c) 2018, 2020 by AsterionDB Inc.                               *
 *                                                                            *
 *  All rights reserved.  No part of this work may be reproduced or otherwise *
 *  incorporated into other works without the express written consent of      *
 *  AsterionDB Inc.                                                           *
 *                                                                            *
 *****************************************************************************/

import React from 'react'

import { Navbar, NavbarBrand, Container, Col, Row, Button, Modal, ModalHeader, ModalBody, ModalFooter } from 'reactstrap'

import ReactTable from 'react-table-6'

import "react-table-6/react-table.css";
import './css/index.css';

import ReactJson from 'react-json-view'

import AppLocalStorage from './AppLocalStorage.js'

import PopupNotification from './PopupNotification'

class Tutorial extends React.Component
{
  "use strict"

  debouncedSaveColumnWidths = null;
  columnKey = 'reactExample';

  buildURL = function(path, parameters)
  {
    let reactExample = '/dbTwig/reactExample';
  
    let dbTwigListener = (window.dbTwigHost !== null ? window.dbTwigHost + reactExample : 
      window.location.protocol + '//' + window.location.hostname  + ':8080' + reactExample);
  
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
  callDbTwig = async function(request, goodResponseHandler, badResponseHandler, errorHandler, extra, logoutErrorIsNonCritical)
  {
    let requestX = request;
    let newHeader = new Headers({ 'Content-Type': 'application/json'});
    requestX = new Request(request, { headers: newHeader});
  
    let self = this;

    fetch(requestX).then(function(response)
    {
      self.fetchComplete(response, goodResponseHandler, badResponseHandler, extra, logoutErrorIsNonCritical, request);
    }).catch(function(error)
    {
      console.log('Fatal error:', error);
      console.log('Faulty request:', request);
      errorHandler('Error: Lost connection to server', extra);
    });
  }
 
  componentDidMount()
  {
    this.fetchInsuranceClaims();
  }

  constructor(props)
  {
    super(props);

    this.appLocalStorage = new AppLocalStorage();

    let listColumns =
    [
      {Header: 'Insured Party', id: 'insuredParty', accessor: 'insuredParty',
        Cell: row => <div><span title='Click for details....'>{row.value}</span></div>},
      {Header: 'Accident Date', id: 'accidentDate', accessor: 'accidentDate',
        Cell: row => <div><span title='Click for details....'>{row.value}</span></div>},
      {accessor: 'claimId', show: false}
    ];

    this.columnWidths = this.appLocalStorage.getColumnWidths(listColumns, this.columnKey);
    this.debouncedSaveColumnWidths = this.debounce(this.saveColumnWidths, 500);

    this.state =
    {
      notificationText: '',
      notificationType: 'info',
      insuranceClaims: [],
      insuranceClaimDetail: undefined,
      listColumns: listColumns,
      modalIsOpen: false,
      modalTitle: '',
      modalMessage: '',
      closable: true,
      selectedRow: null
    }

    this.selectionHandler = this.selectionHandler.bind(this);
    this.fetchInsuranceClaimDetail = this.fetchInsuranceClaimDetail.bind(this);
    this.toggleModal = this.toggleModal.bind(this);
  }
      
  debounce = function(func, wait, immediate)
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

  /*
  * DO NOT CALL DIRECTLY; Only intended for use with window.apiRequest - see above
  */
  fetchComplete(response, goodResponseHandler, badResponseHandler, extra, logoutErrorIsNonCritical, request)
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

  fetchInsuranceClaims()
  {
    let self = this;

    this.callDbTwig(new Request(this.buildURL('/getInsuranceClaims')),
      function(response, jsonData)
      {
        let selectedRow = null;
        if (jsonData.length)
        {
          selectedRow = 0;
          self.fetchInsuranceClaimDetail(jsonData[0].claimId);
        }
        self.setState({insuranceClaims: jsonData, selectedRow: selectedRow});
      },
      function(response, jsonData)
      {
        self.openAppModal('Error fetching insurance claims', jsonData.errorMessage, true);
      },
      function(errorMessage)
      {
        self.postNotification('error', errorMessage);
      });
  }

  fetchInsuranceClaimDetail(claimId)
  {
    var bodyData = { databaseUsername: this.databaseUsername, claimId: claimId };
    let self = this;

    this.callDbTwig(new Request(this.buildURL('/getInsuranceClaimDetail'), 
        {method: "POST", body: JSON.stringify(bodyData)}),
      function(response, jsonData)
      {
        self.setState({insuranceClaimDetail: jsonData});
      },
      function(response, jsonData)
      {
        self.openAppModal('Error fetching insurance claim detail', jsonData.errorMessage, true);
      },
      function(errorMessage)
      {
        self.postNotification('error', errorMessage);
      });
  }

  openAppModal(modalTitle, modalMessage, closable)
  {
    this.setState(
    {
      modalTitle: modalTitle,
      modalMessage: modalMessage,
      closable: closable,
      modalIsOpen: true,
    });
  }

 postNotification(notificationType, notificationText)
 {
   this.setState({ notificationText: notificationText, notificationType: notificationType });
 }

 render()
  {
    let modalFooter = null;
    if (this.state.closable)
      modalFooter = (
        <ModalFooter>
          <Button color="secondary" onClick={this.toggleModal} autoFocus>OK</Button>
        </ModalFooter>
      );

    let columns =
    [
      {id: 'mediaUrl', accessor: 'mediaUrl',
        Cell: (rowInfo) =>
        (
          <div><img alt='no text' src={rowInfo.row.mediaUrl}/></div>
        )
      }
    ]

    let claimPhotos = (undefined === this.state.insuranceClaimDetail ? undefined : this.state.insuranceClaimDetail.claimPhotos);
    let claimReport = (undefined === this.state.insuranceClaimDetail ? null : 
      (<a href={this.state.insuranceClaimDetail.claimsAdjusterReport} target="_blank" rel="noopener noreferrer"><Button >View</Button></a> ));

    return(
      <div>
        <Navbar className='bg-primary' dark fixed="top" expand="md" >
          <NavbarBrand target="_blank" rel="noopener noreferrer" href="https://www.asteriondb.com"><img alt='AsterionDB' width={20} src='assets/images/asteriondb_logo.png' /> AsterionDB</NavbarBrand>
        </Navbar>
        <Container fluid>
          <PopupNotification notificationText={this.state.notificationText} notificationType={this.state.notificationType} clearNotifier={this.clearNotifier}/>
          <Modal isOpen={this.state.modalIsOpen} toggle={this.toggleModal} autoFocus={false}> 
            <ModalHeader toggle={this.toggleModal}>{this.state.modalTitle}</ModalHeader>
            <ModalBody>
              <Row><Col>{this.state.modalMessage}</Col></Row>
            </ModalBody>
            {modalFooter}
          </Modal>
          <Row><Col sm='4' style={{textAlign: 'center'}}><h2>Insurance Claims</h2></Col><Col sm='8' style={{textAlign: 'center'}}><h2>Claim Details</h2></Col></Row>
          <Row >
            <Col sm='4'>
              <Row style={{paddingTop: '10px'}}><Col>
                <ReactTable columns={this.state.listColumns} data={this.state.insuranceClaims} minRows={1} className="-striped -highlight" 
                  onResizedChange={(resizedColumns, event) => this.debouncedSaveColumnWidths(resizedColumns, event)} 
                  getTrProps={(state, rowInfo, column) => 
                  { 
                    if (rowInfo === undefined) return { };                
                    if (rowInfo.index === this.state.selectedRow)
                      return {style: {fontWeight: "bold", color: "#ffffff", backgroundColor: "#0275d8"}}
                    else
                      return {} 
                  }}            
                  getTdProps={(state, rowInfo, column, instance) => {
                    let whiteSpace = 'no-wrap';
                    return {
                      onClick: (e, handleOriginal) => {this.selectionHandler(e, handleOriginal, rowInfo, column, instance)},
                      style: {whiteSpace: whiteSpace}
                    }
                  }}
                />
              </Col></Row>
              <Row style={{paddingTop: '10px'}}><Col><ReactJson src={this.state.insuranceClaimDetail}/></Col></Row>
            </Col>
            <Col sm='8'>
              <Row><Col sm='3'>Insured Party</Col><Col>{(undefined !== this.state.insuranceClaimDetail ? this.state.insuranceClaimDetail.insuredParty : null)}</Col></Row>
              <Row><Col sm='3'>Accident Location</Col><Col>{(undefined !== this.state.insuranceClaimDetail ? this.state.insuranceClaimDetail.accidentLocation : null)}</Col></Row>
              <Row><Col sm='3'>Accident Date</Col><Col>{(undefined !== this.state.insuranceClaimDetail ? this.state.insuranceClaimDetail.accidentDate : null)}</Col></Row>          
              <Row><Col sm='3'>Deductible Amount</Col><Col>{(undefined !== this.state.insuranceClaimDetail ? this.state.insuranceClaimDetail.deductibleAmount : null)}</Col></Row>                      
              <Row><Col sm='3'>Claims Adjuster's Report</Col><Col>{claimReport}</Col></Row>                      
              <Row>
                <Col sm='3'>Photograph's</Col>
                <Col><ReactTable columns={columns} data={claimPhotos} showPagination={false} minRows={1}/></Col>
              </Row>
            </Col>
          </Row>
        </Container>
      </div>
    );
  }

  saveColumnWidths(resizedColumns)
  {
    this.appLocalStorage.saveColumnWidths(resizedColumns, this.columnWidths, this.columnKey);
  }

  selectionHandler(event, handleOriginal, rowInfo, column, instance)
  {
    this.setState({selectedRow: rowInfo.index});
    this.fetchInsuranceClaimDetail(rowInfo.row.claimId);
  }

  toggleModal()
  {
    // when modal footer is hidden, the modal should not be close-able
    if (!this.state.closable) return; 

    this.setState(
    {
      modalIsOpen: !this.state.modalIsOpen
    });
  }
}

export default Tutorial