/******************************************************************************
 *                                                                            *
 *  Copyright (c) 2018, 2020 by AsterionDB Inc.                               *
 *                                                                            *
 *  All rights reserved.  No part of this work may be reproduced or otherwise *
 *  incorporated into other works without the express written consent of      *
 *  AsterionDB Inc.                                                           *
 *                                                                            *
 *****************************************************************************/

class AppLocalStorage
{
  "use strict"

  keyStub = null;

  clear()
  {
    let keys = [];
    for (let x = 0; x < localStorage.length; x++)
    {
      if (this.keyStub === localStorage.key(x).substring(0, this.keyStub.length))
        keys.push(localStorage.key(x));
    }

    for (let x = 0; x < keys.length; x++) localStorage.removeItem(keys[x]);
  }

  constructor()
  {
    this.keyStub = 'dbTwig.';
  }

  getColumnWidths(columns, key)
  {
    let columnWidths = JSON.parse(this.getItem(key));
    if (columnWidths === null || 'null' === columnWidths)
      return {};
    else
    {
      for (let i = 0; i < columns.length; i++)
      {
        var columnName;
        for (columnName in columnWidths)
        {
          if (columnWidths.hasOwnProperty(columnName) && columns[i].id === columnName)
          {
            columns[i].width = columnWidths[columnName];
            break;
          }
        }
      }
    }
  
    return columnWidths;
  }    

  getItem(key)
  {
    return localStorage.getItem(this.keyStub + key);
  }

  saveColumnWidths(resizedColumns, columnWidths, key)
  {
    for (let i = 0; i < resizedColumns.length; i++)
    {
      columnWidths[resizedColumns[i].id] = resizedColumns[i].value;
    }
    this.setItem(key, JSON.stringify(columnWidths));
  }
  
  setItem(key, value)
  {
    localStorage.setItem(this.keyStub + key, value);
  }
}

export default AppLocalStorage