DROP PACKAGE PRISM_DELPHI_DATA_PKG;

CREATE OR REPLACE PACKAGE            PRISM_DELPHI_DATA_PKG AS
/******************************************************************************
   NAME:     PRISM_DELPHI_DATA_PKG 
   Purpose : Populate the Prism requisition and Delphi purchase order information
             to KITT's database to be used to track task orders.
              
   REVISIONS:
   Ver        Date        Author           
   ---------  ----------  --------------- 
   1.0        1/29/2009    Surekha Kandula
******************************************************************************/

         
  PROCEDURE P_MOVE_HOLD_TO_BASE(V_ERROR_CODE OUT NUMBER, V_ERROR_BUFF OUT VARCHAR2);                    
  
END PRISM_DELPHI_DATA_PKG; 
/

DROP PACKAGE BODY PRISM_DELPHI_DATA_PKG;

CREATE OR REPLACE PACKAGE BODY            PRISM_DELPHI_DATA_PKG AS

  /******************************************************************************
     NAME:      P_MOVE_PRISM_LIVE_TO_ARCHIVE
     PURPOSE:   Procedure to archive PRISM PR data.
  
     REVISIONS: 1.0
     Date:   1/29/2009
   ******************************************************************************/
  
 PROCEDURE P_MOVE_HOLD_TO_BASE(V_ERROR_CODE OUT NUMBER, V_ERROR_BUFF OUT VARCHAR2)
 IS
 
 BEGIN
 
 
   KITT_KFDBUSER.P_MOVE_HOLD_TO_BASE(V_ERROR_CODE, V_ERROR_BUFF);
  dbms_output.put_line(V_ERROR_CODE||'-'|| V_ERROR_BUFF);
  

 
 END; 
     

END PRISM_DELPHI_DATA_PKG; 
/
