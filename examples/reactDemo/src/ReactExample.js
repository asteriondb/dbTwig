/******************************************************************************
 *                                                                            *
 *  Copyleft (:-) 2020, 2024 by AsterionDB Inc.                               *
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

import { Input, Navbar, NavbarBrand, Container, Col, Row, Button, Modal, ModalHeader, ModalBody, ModalFooter,
  Nav, NavItem, NavLink, TabContent, TabPane } from 'reactstrap'
import classnames from 'classnames';

import ReactTable from 'react-table-legacy'

import "react-table-legacy/react-table.css";
import './css/index.css';

import { JsonView } from 'react-json-view-lite';
import 'react-json-view-lite/dist/index.css';

import AppLocalStorage from './AppLocalStorage.js'

import PopupNotification from './PopupNotification'

import { css } from '@emotion/react';
import { RingLoader } from 'react-spinners'

import { Gallery } from 'react-grid-gallery';

class Tutorial extends React.Component
{

  debouncedSaveColumnWidths = null;
  columnKey = 'reactExample';

  dbTwig = require('./DbTwig.js');

  clearNotifier()
  {
    this.setState({ notificationText: '' });
  }
  
  componentDidMount()
  {
    this.fetchMaintenanceManuals();
  }

  constructor(props)
  {
    super();  

    this.appLocalStorage = new AppLocalStorage();

    let listColumns =
    [
      {Header: 'Manufacturer', id: 'manufacturer', accessor: 'manufacturer',
        Cell: row => <div><span title='Click for details....'>{row.value}</span></div>},
      {Header: 'In Service From', id: 'inServiceFrom', accessor: 'inServiceFrom',
        Cell: row => <div><span title='Click for details....'>{row.value}</span></div>},
      {accessor: 'manualId', show: false}
    ];

    this.columnWidths = this.appLocalStorage.getColumnWidths(listColumns, this.columnKey);
    this.debouncedSaveColumnWidths = this.debounce(this.saveColumnWidths, 500);

    this.state =
    {
      notificationText: '',
      notificationType: 'info',
      maintenanceManuals: [],
      manualDetail: undefined,
      listColumns: listColumns,
      modalIsOpen: false,
      modalTitle: '',
      modalMessage: '',
      selectedRow: null,
      techNote: '', 
      tabIndex: 0,
      headshots: [],
      processedHeadshots: [],
      spinnerIsSpinning: false,
      detectionDisabled: false
    }

    this.selectionHandler = this.selectionHandler.bind(this);
    this.fetchMaintenanceManualDetail = this.fetchMaintenanceManualDetail.bind(this);
    this.saveTechNote = this.saveTechNote.bind(this);
    this.setTechNotes = this.setTechNotes.bind(this);
    this.toggleModal = this.toggleModal.bind(this);
    this.clearNotifier = this.clearNotifier.bind(this);
    this.toggleTab = this.toggleTab.bind(this);
    this.getHeadshots = this.getHeadshots.bind(this);
    this.objectDetectionButton = this.objectDetectionButton.bind(this);
    this.objectTrackingButton = this.objectTrackingButton.bind(this);

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

  async editPartsSpreadsheet(spreadsheetId)
  {
    var bodyData = {};

    bodyData.spreadsheetId = this.state.manualDetail.spreadsheetId;
    let result = await this.dbTwig.callRestAPI('dbTwigExample', 'editSpreadsheet', bodyData);
    if ('success' !== result.status)
    {
      return this.dbTwig.apiErrorHandler(result, 'Error editing spreadsheet.');
    } 
  }

  async fetchMaintenanceManuals()
  {
    let result = await this.dbTwig.callRestAPI('dbTwigExample', 'getMaintenanceManuals');
    if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to fetch maintenance manuals.');

    let selectedRow = null;
    if (result.jsonData.length)
    {
      selectedRow = 0;
      this.fetchMaintenanceManualDetail(result.jsonData[0].manualId);
    }
    this.setState({maintenanceManuals: result.jsonData, selectedRow: selectedRow});
  }

  async fetchMaintenanceManualDetail(manualId)
  {
    let bodyData = { databaseUsername: this.databaseUsername, manualId: manualId };

    let result = await this.dbTwig.callRestAPI('dbTwigExample', 'getMaintenanceManualDetail', bodyData);
    if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to fetch maintenance manual detail');
    this.setState({manualDetail: result.jsonData});
  }

  async getHeadshots()
  {
    let result = await this.dbTwig.callRestAPI('openCV', 'getHeadshots');
    if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to fetch headshots.');
    let headshots = [];
    for (let x = 0; x < result.jsonData.headshots.length; x++)
    {
      let headshot = {};
      headshot.src = result.jsonData.headshots[x].objectWeblink;
      headshot.width = 256;
      headshots.push(headshot);
    }

    let processedHeadshots = [];
    for (let x = 0; x < result.jsonData.processedHeadshots.length; x++)
    {
      let headshot = {};
      headshot.src = result.jsonData.processedHeadshots[x].objectWeblink;
      headshot.width = 256;
      processedHeadshots.push(headshot);
    }

    this.setState({headshots, processedHeadshots});
  }

  async objectDetectionButton()
  {
    if (this.state.processedHeadshots.length)
    {
      let result = await this.dbTwig.callRestAPI('openCV', 'resetDemo');
      if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to reset the demo.');
      this.setState({processedHeadshots: []});
      this.postNotification('success', 'Object detection demo reset...');
    }
    else
    {
      this.postNotification('info', 'Object detection process is running....Please wait...');
      this.setState({spinnerIsSpinning: true, detectionDisabled: true});
      let result = await this.dbTwig.callRestAPI('openCV', 'processHeadshots');
      this.setState({spinnerIsSpinning: false, detectionDisabled: false});
      if ('success' !== result.status) return this.dbTwig.apiErrorHandler(result, 'Unable to process the headshots.');
      this.getHeadshots();
      this.postNotification('success', 'Object detection process complete.');
    }
  }

  async objectTrackingButton()
  {
    let result = await this.dbTwig.callRestAPI('openCV', 'trackAnObject');
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
    const override = css`
      display: block;
      margin: 0 auto;
      border-color: red;
    `;
    
    let columns =
    [
      {id: 'mediaLink', accessor: 'mediaLink',
        Cell: (rowInfo) =>
        (
          <div><img alt='no text' src={rowInfo.row.mediaLink}/></div>
        )
      }
    ]

    let majorAssemblies = (undefined === this.state.manualDetail ? undefined : this.state.manualDetail.assemblyPhotos);
    let maintenanceManualLink = (undefined === this.state.manualDetail ? null : 
      (<a href={this.state.manualDetail.maintenanceManualLink} target="_blank" rel="noopener noreferrer"><Button >View</Button></a> ));

    let editButtonDisabled = undefined !== this.state.manualDetail && null !== this.state.manualDetail.spreadsheetId ? false : true;
    let spreadsheetId = undefined === this.state.manualDetail ? null : this.state.manualDetail.spreadsheetId;

    let objectDetectionButtonText = 'Process Headshots';
    if (undefined !== this.state.processedHeadshots && this.state.processedHeadshots.length) objectDetectionButtonText = 'Reset Demo';

    return(
      <div>
        <Navbar className='bg-primary' dark fixed="top" expand="md" >
          <NavbarBrand>React Based Demo Apps</NavbarBrand>
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
          <Nav tabs>
            <NavItem>
              <NavLink className={classnames({ active: this.state.tabIndex === 0 })}
                onClick={() => { this.toggleTab(0); }}
              >
                App Integration
              </NavLink>
            </NavItem>
            <NavItem>
              <NavLink className={classnames({ active: this.state.tabIndex === 1 })}
                onClick={() => { this.toggleTab(1); }}
              >
                Object Detection
              </NavLink>
            </NavItem>
            <NavItem>
              <NavLink className={classnames({ active: this.state.tabIndex === 2 })}
                onClick={() => { this.toggleTab(2); }}
              >
                Object Tracking
              </NavLink>
            </NavItem>
          </Nav>
          <TabContent activeTab={this.state.tabIndex}>
            <TabPane tabId={0}>
              <Row><Col sm='4' style={{textAlign: 'center'}}><h2>Maintenance Manuals</h2></Col><Col sm='8' style={{textAlign: 'center'}}><h2>Manual Details</h2></Col></Row>
              <Row >
                <Col sm='4'>
                  <Row style={{paddingTop: '10px'}}><Col>
                    <ReactTable columns={this.state.listColumns} data={this.state.maintenanceManuals} minRows={1} className="-striped -highlight" 
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
                  <Row style={{paddingTop: '10px'}}>
                    <Col sm='9'>
                      <Input type="text" id="techNote" placeholder="Enter some text..." value={this.state.techNote} onChange={this.setTechNotes}/>
                    </Col>
                    <Col sm={1}>
                      <Button onClick={this.saveTechNote} color="primary">Save</Button>
                    </Col>
                  </Row>
                  { (undefined !== this.state.manualDetail) &&
                    <Row style={{paddingTop: '10px'}}><Col><JsonView data={this.state.manualDetail}/></Col></Row>
                  }
                </Col>
                <Col sm='8'>
                  <Row><Col sm='3'>Manufacturer</Col><Col>{(undefined !== this.state.manualDetail ? this.state.manualDetail.manufacturer : null)}</Col></Row>
                  <Row><Col sm='3'>Maintenance Division</Col><Col>{(undefined !== this.state.manualDetail ? this.state.manualDetail.maintenanceDivision : null)}</Col></Row>
                  <Row><Col sm='3'>In Service From</Col><Col>{(undefined !== this.state.manualDetail ? this.state.manualDetail.inServiceFrom : null)}</Col></Row>          
                  <Row><Col sm='3'>Revision #</Col><Col>{(undefined !== this.state.manualDetail ? this.state.manualDetail.revisionNumber : null)}</Col></Row>                      
                  <Row><Col sm='3'>Maintenance Manual</Col><Col>{maintenanceManualLink}</Col></Row>                      
                  <Row style={{paddingTop: '10px'}}>
                    <Col sm='3'>Parts Spreadsheet</Col>
                    <Col>
                      <Button disabled={editButtonDisabled}
                        onClick={this.editPartsSpreadsheet.bind(this, spreadsheetId)}>Edit</Button>
                    </Col>
                  </Row>
                  <Row style={{paddingTop: '10px'}}>
                    <Col sm='3'>Major Assemblies</Col>
                    <Col><ReactTable columns={columns} data={majorAssemblies} showPagination={false} minRows={1}/></Col>
                  </Row>
                </Col>
              </Row>
            </TabPane>
            <TabPane tabId={1}>
              <Row style={{paddingTop: '10px'}}>
                <Col><Button disabled={this.state.detectionDisabled} onClick={this.objectDetectionButton}>{objectDetectionButtonText}</Button></Col>
                <Col>Provide some descriptive text....</Col>
              </Row>
              <Row style={{paddingTop: '10px'}}>
                <Col sm='2'>Headshots</Col>
                <Col><Gallery images={this.state.headshots}></Gallery></Col>
              </Row>
            { 0 !== this.state.processedHeadshots.length &&
              <Row style={{paddingTop: '10px'}}>
                <Col sm='2'>Processed Headshots</Col>
                <Col><Gallery images={this.state.processedHeadshots}></Gallery></Col>
              </Row>
            }
              <div style={{position: "fixed", top: "50%", left: "50%", transform: "translate(-50%, -50%)"}}>
                <RingLoader
                  css={override}
                  size={75}
                  color={'#4A90E2'}
                  loading={this.state.spinnerIsSpinning}
                />          
              </div>
            </TabPane>
            <TabPane tabId={2}>
              Object Tracking...
              <Button onClick={this.objectTrackingButton}>Object Tracking Demo</Button>
            </TabPane>
          </TabContent>
        </Container>
      </div>
    );
  }

  async saveTechNote()
  {
    var bodyData = {};

    bodyData.techNote = this.state.techNote;
    bodyData.manualId = this.state.maintenanceManuals[this.state.selectedRow].manualId;
    let result = await this.dbTwig.callRestAPI('dbTwigExample', 'saveTechNote', bodyData);
    if ('success' !== result.status)
    {
      return this.dbTwig.apiErrorHandler(result, 'Error saving claim note.');
    } 

    this.setState({techNote: ''});
  }

  saveColumnWidths(resizedColumns)
  {
    this.appLocalStorage.saveColumnWidths(resizedColumns, this.columnWidths, this.columnKey);
  }

  selectionHandler(event, handleOriginal, rowInfo, column, instance)
  {
    this.setState({selectedRow: rowInfo.index});
    this.fetchMaintenanceManualDetail(rowInfo.row.manualId);
  }

  setTechNotes(event)
  {
    this.setState({techNote: event.target.value});
  }

  toggleModal()
  {
    this.setState(
    {
      modalIsOpen: !this.state.modalIsOpen
    });
  }

  toggleTab(tabIndex)
  {
    if (1 === tabIndex) this.getHeadshots();
    
    this.setState({tabIndex});
  }
}

export default Tutorial