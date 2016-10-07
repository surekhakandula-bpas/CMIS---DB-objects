DROP PROCEDURE TOOL_DEALLOCATE_CREDIT;

CREATE OR REPLACE PROCEDURE           TOOL_DEALLOCATE_CREDIT IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       TOOL_DEALLOCATE_CREDIT
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        3/16/2010          1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     TOOL_DEALLOCATE_CREDIT
      Sysdate:         3/16/2010
      Date and Time:   3/16/2010, 3:07:43 PM, and 3/16/2010 3:07:43 PM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
BEGIN
   
/*
    for c in ( select a.N_ALLOCATION_ID, a.N_SUB_TASK_ORDER_ID,a.N_USER_PROFILE_ID,
                      a.N_DELPHI_OBLIGATION_ID,a.N_ETO_ID,a.N_ALLOCATION_AMOUNT,a.N_DEALLOCATION_AMOUNT,
                      a.D_ALLOCATION_DATE, a.F_FEE, a.F_CREDIT 
                      from ALLOCATION a 
                      where a.F_CREDIT='Y') loop
                      
         insert into ALLOCATION (N_ALLOCATION_ID, N_SUB_TASK_ORDER_ID,N_USER_PROFILE_ID,
                      N_DELPHI_OBLIGATION_ID,N_ETO_ID,N_ALLOCATION_AMOUNT,N_DEALLOCATION_AMOUNT,
                      D_ALLOCATION_DATE, F_FEE, F_CREDIT )
                values (SEQ_ALLOCATION.nextval,
                        c.N_SUB_TASK_ORDER_ID, c.N_USER_PROFILE_ID,
                      c.N_DELPHI_OBLIGATION_ID,c.N_ETO_ID,0, c.N_ALLOCATION_AMOUNT,
                      sysdate, c.F_FEE, c.F_CREDIT ); 
                      
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
END TOOL_DEALLOCATE_CREDIT; 
/
