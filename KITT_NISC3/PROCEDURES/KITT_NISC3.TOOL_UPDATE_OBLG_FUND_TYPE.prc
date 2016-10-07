DROP PROCEDURE TOOL_UPDATE_OBLG_FUND_TYPE;

CREATE OR REPLACE PROCEDURE            TOOL_UPDATE_OBLG_FUND_TYPE IS

/******************************************************************************
  
   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/25/2010    Chao Yu     1. Created this procedure.

   NOTES:

   Use this stored procedure to fix the wrong funding type in delphi obligation table,
   when funding type is updated in KFDB, but not updated in delphi obligation table.
   
   steps;
   
   1) import the the lines which need to be fixed into table UTI_TEMP_DELPHI_OBLI_FUND_TYPE
   2) Run following query to find the mix flag in task order table.
   
     select distinct a.*, d.C_TASK_ORDER_NUMBER, d.N_FUNDING_TYPE_ID, d.F_MIX_FUNDS 
            from UTI_TEMP_DELPHI_OBLI_FUND_TYPE a, allocation b, sub_task_order c, task_order d
            where a.N_DELPHI_OBLIGATION_ID = b.N_DELPHI_OBLIGATION_ID
             and b.N_SUB_TASK_ORDER_ID = c.N_SUB_TASK_ORDER_ID
             and c.N_TASK_ORDER_ID = d.N_TASK_ORDER_ID 
   3) Change the mix flag to 'Y' after getting a approval.
   4) Back up current delphi obligation table.
   5) Run this stored procedure to update the funding type in delphi obligation table.

******************************************************************************/



BEGIN
   
/*
      for c in ( select N_DELPHI_OBLIGATION_ID, trim(NTDB_KFDBC_FUNDING_TYPE ) as NEW_FUND_TYPE 
                   from UTI_TEMP_DELPHI_OBLI_FUND_TYPE ) loop
      
         update delphi_obligation
           set C_FUNDING_TYPE = c.NEW_FUND_TYPE,
               C_TYPE_OF_FUNDS = c.NEW_FUND_TYPE
         where N_DELPHI_OBLIGATION_ID = c.N_DELPHI_OBLIGATION_ID;
      
         dbms_output.put_line('ID: ' || c.N_DELPHI_OBLIGATION_ID ||'; NEW FUND: '||c.NEW_FUND_TYPE);
         
      end loop;
      
      commit;
*/
null;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       rollback;
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_UPDATE_OBLG_FUND_TYPE; 
/
