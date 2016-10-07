DROP PROCEDURE TOOL_ADJ_CREDIT;

CREATE OR REPLACE PROCEDURE           TOOL_ADJ_CREDIT IS
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
   for c in ( select  N_DELPHI_OBLIGATION_ID,  KITT_SUB_TO_ID, N_ETO_ID, AMOUNT 
                from V_TOOL_ADJ_CREDIT ) loop
           
           insert into ALLOCATION
                ( N_ALLOCATION_ID, 
                  N_DELPHI_OBLIGATION_ID,
                  N_SUB_TASK_ORDER_ID, 
                  N_ETO_ID,
                  N_USER_PROFILE_ID,
                  N_ALLOCATION_AMOUNT,
                  N_DEALLOCATION_AMOUNT,
                  D_ALLOCATION_DATE,
                  F_FEE,
                  F_CREDIT)
             values
                ( SEQ_ALLOCATION.nextval,
                  c.N_DELPHI_OBLIGATION_ID,
                  c.KITT_SUB_TO_ID,
                  c.N_ETO_ID,
                  100,
                  c.AMOUNT * (-1),
                  0,
                  sysdate,
                  'N',
                  'Y');
                  
   
   end loop;
   commit;  
*/ null;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END; 
/
