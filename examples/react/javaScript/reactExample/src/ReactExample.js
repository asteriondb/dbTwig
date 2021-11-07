/******************************************************************************
 *                                                                            *
 *  Copyleft (:-) 2020, 2021 by AsterionDB Inc.                               *
 *                                                                            *
 *  ReactExample.js - A simple little JScript React SPA that interacts with   *
 *  DbTwig and AsterionDB.                                                    *
 *                                                                            *
 *  This software provides an example of how one interacts with DbTwig.       *
 *                                                                            *
 *  The entire point of this software is to show you how to integrate calls   *
 *  to DbTwig into your application.
 *                                                                            *
 *  No rights claimed or implied. This software is not to be used in a        *
 *  production setting without modifcation and customization by the end user. *
 *  End user accepts all responsibilities by using this software as a basis   *
 *  for development and instruction.                                          *
 *                                                                            *
 *  This software is not claimed to be, nor guaranteed to be free from defect *
 *  or error.                                                                 *
 *                                                                            *
 *  This software is to be used by the end user as a basis for instruction    *
 *  and as a template for implementation in production use cases.             *
 *                                                                            *
 *  End users are not required to post their modifications for others to use. *
 *                                                                            *
 *  This software is un-licensed and free to use in any manner you choose.    *
 *                                                                            *
 *****************************************************************************/

import React from 'react'

import { Navbar, NavbarBrand, Container, Col, Row, Button, Modal, ModalHeader, ModalBody, ModalFooter } from 'reactstrap'

import ReactTable from 'react-table-legacy'

import "react-table-legacy/react-table.css";
import './css/index.css';

import ReactJson from 'react-json-view'

import AppLocalStorage from './AppLocalStorage.js'

import PopupNotification from './PopupNotification'

class Tutorial extends React.Component
{
  "use strict"

  debouncedSaveColumnWidths = null;
  columnKey = 'reactExample';

  dbTwig = require('./DbTwig.js');

  clearNotifier()
  {
    this.setState({ notificationText: '' });
  }

  componentDidMount()
  {
    this.fetchInsuranceClaims();
  }

  constructor(props)
  {
    super();

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
      selectedRow: null
    }

    this.selectionHandler = this.selectionHandler.bind(this);
    this.fetchInsuranceClaimDetail = this.fetchInsuranceClaimDetail.bind(this);
    this.toggleModal = this.toggleModal.bind(this);
    this.clearNotifier = this.clearNotifier.bind(this);

    window.openAppModal = this.openAppModal.bind(this);
    window.postNotification = this.postNotification.bind(this);
  }
      
  debounce = function(func, wait, immediate)
  {
    let timeout;
    return function()
    {
      let context = this, args = arguments;
      let later = function()
      {
        timeout = null;
        if (!immediate) func.apply(context, args);
      };
      let callNow = immediate && !timeout;
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
      if (callNow) func.apply(context, args);
    };
  }

  async fetchInsuranceClaims()
  {
    let result = await this.dbTwig.callRestAPI('getInsuranceClaims');
    if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to fetch insurance claims.');

    let selectedRow = null;
    if (result.jsonData.length)
    {
      selectedRow = 0;
      this.fetchInsuranceClaimDetail(result.jsonData[0].claimId);
    }
    this.setState({insuranceClaims: result.jsonData, selectedRow: selectedRow});
  }

  async fetchInsuranceClaimDetail(claimId)
  {
    let bodyData = { databaseUsername: this.databaseUsername, claimId: claimId };

    let result = await this.dbTwig.callRestAPI('getInsuranceClaimDetail', bodyData);
    if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to fetch insurance claim detail');
    this.setState({insuranceClaimDetail: result.jsonData});
  }

  openAppModal(modalTitle, modalMessage)
  {
    this.setState(
    {
      modalTitle: modalTitle,
      modalMessage: modalMessage,
      modalIsOpen: true,
    });
  }

  postNotification(notificationType, notificationText)
  {
    this.setState({ notificationText: notificationText, notificationType: notificationType });
  }

  render()
  {
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
          <NavbarBrand target="_blank" rel="noopener noreferrer" href="https://www.asteriondb.com"><img alt='AsterionDB' width={20} src='assets/images/icon150x150.png' /></NavbarBrand>
        </Navbar>
        <Container fluid>
          <PopupNotification notificationText={this.state.notificationText} notificationType={this.state.notificationType} clearNotifier={this.clearNotifier}/>
          <Modal isOpen={this.state.modalIsOpen} toggle={this.toggleModal} autoFocus={false}> 
            <ModalHeader toggle={this.toggleModal}>{this.state.modalTitle}</ModalHeader>
            <ModalBody>
              <Row><Col>{this.state.modalMessage}</Col></Row>
            </ModalBody>
            <ModalFooter>
              <Button color="secondary" onClick={this.toggleModal} autoFocus>OK</Button>
            </ModalFooter>
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
    this.setState(
    {
      modalIsOpen: !this.state.modalIsOpen
    });
  }
}

export default Tutorial