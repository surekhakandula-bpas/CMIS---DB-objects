DROP PROCEDURE TOOL_SET_CREDIT_ETOID;

CREATE OR REPLACE PROCEDURE           TOOL_SET_CREDIT_ETOID IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       TOOL_SET_CREDIT_ETOID
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/12/2010          1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     TOOL_SET_CREDIT_ETOID
      Sysdate:         4/12/2010
      Date and Time:   4/12/2010, 12:55:51 PM, and 4/12/2010 12:55:51 PM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
BEGIN
   
     for c in ( SELECT TAO.N_ETO_ID, DOA.N_INVOICE_ITEM_ID,  DOA.N_DELPHI_OBLIGATION_ID
                  FROM CREDIT DOA,INVOICE_ITEM II,SUB_TASK_ORDER STO , task_order TAO
                 WHERE DOA.N_INVOICE_ITEM_ID = II.N_INVOICE_ITEM_ID
                   AND II.N_SUB_TASK_ORDER_ID = STO.N_SUB_TASK_ORDER_ID
                   AND STO.N_TASK_ORDER_ID = TAO.N_TASK_ORDER_ID
                   AND DOA.N_ETO_ID is null ) loop
             
         
            update CREDIT
              set N_ETO_ID = c.N_ETO_ID
             where N_INVOICE_ITEM_ID = c.N_INVOICE_ITEM_ID
               and N_DELPHI_OBLIGATION_ID = c.N_DELPHI_OBLIGATION_ID;
             
     end loop;
     commit;
     
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_SET_CREDIT_ETOID; 
/
