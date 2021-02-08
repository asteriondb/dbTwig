/******************************************************************************
 *                                                                            *
 *  Copyright (c) 2018, 2021 by AsterionDB Inc.                               *
 *                                                                            *
 *  All rights reserved.  No part of this work may be reproduced or otherwise *
 *  incorporated into other works without the express written consent of      *
 *  AsterionDB Inc.                                                           *
 *                                                                            *
 *****************************************************************************/

import React from 'react'
import { ToastContainer } from 'react-toastr';

import './css/animate.min.css'
import './css/toastr.min.css'

class PopupNotification extends React.Component
{
  componentDidUpdate(prevProps, prevState)
  {
    if (this.props.notificationText !== '')
    {
      switch (this.props.notificationType)
      {
        case 'success':
          this.refs.popupNotification.success(this.props.notificationText, '',
            {"showAnimation": "animated fadeInUp", "hideAnimation": "animated fadeOutUp"});
          break;

        case 'info':
          this.refs.popupNotification.info(this.props.notificationText, '',
            {"showAnimation": "animated fadeInUp", "hideAnimation": "animated fadeOutUp"});
          break;

        case 'warning':
          this.refs.popupNotification.warning(this.props.notificationText, '',
            {"showAnimation": "animated fadeInUp", "hideAnimation": "animated fadeOutUp"});
          break;

        case 'error':
          this.refs.popupNotification.error(this.props.notificationText, '',
            {"showAnimation": "animated fadeInUp", "hideAnimation": "animated fadeOutUp"});
          break;

        default:
          break;
      }
      
      if (this.props.clearNotifier !== undefined)
        this.props.clearNotifier();
    }
  }

  render()
  {
    return(
      <ToastContainer
        ref='popupNotification'
        className="toast-top-right"
        newestOnTop={false} 
      />
    );
  }
}

export default PopupNotification
