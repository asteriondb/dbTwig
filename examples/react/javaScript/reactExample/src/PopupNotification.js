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
import { ToastContainer, toast } from 'react-toastify';

import 'react-toastify/dist/ReactToastify.min.css';

class PopupNotification extends React.Component
{
  componentDidUpdate(prevProps, prevState)
  {
    if (this.props.notificationText !== '')
    {
      switch (this.props.notificationType)
      {
        case 'success':
          toast.success(this.props.notificationText);
          break;

        case 'info':
          toast.info(this.props.notificationText);
          break;

        case 'warning':
          toast.warning(this.props.notificationText);
          break;

        case 'error':
          toast.error(this.props.notificationText);
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
      <ToastContainer />
    );
  }
}

export default PopupNotification
