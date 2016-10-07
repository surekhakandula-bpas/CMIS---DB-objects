DROP PROCEDURE TOOL_ADJ_AP_PAYMENT_ADJ;

CREATE OR REPLACE PROCEDURE           TOOL_ADJ_AP_PAYMENT_ADJ IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       TOOL_ADJ_AP_PAYMENT_ADJ
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        1/5/2010    Chao Yu      1. Created this procedure.

   NOTES:

   
******************************************************************************/
BEGIN
  
/*
   for c in ( select  N_DELPHI_OBLIGATION_ID, N_PAYMENT_INSTRUCTION_ID, KITT_SUB_TO_ID,AMOUNT 
                from V_TOOL_ADJ_AP_PAYMENT_ADJ ) loop
           
        insert into PAYMENT_INSTRUCTION_ITEM
                  ( N_PAYMENT_INSTRUCTION_ITEM_ID,
                    N_PAYMENT_INSTRUCTION_ID,
                    N_DELPHI_OBLIGATION_ID,
                    N_SUB_TASK_ORDER_ID,
                    N_AMOUNT,
                    F_FEE )
                values
                  ( SEQ_PAYMENT_INSTRUCTION_ITEM.nextval,
                    c.N_PAYMENT_INSTRUCTION_ID,
                    c.N_DELPHI_OBLIGATION_ID,
                    c.KITT_SUB_TO_ID,
                    c.AMOUNT,
                    'N');
                    
              
     
   end loop;
   commit;  
*/
null;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_ADJ_AP_PAYMENT_ADJ; 
/
