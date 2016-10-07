DROP PROCEDURE TOOL_PMO_REFRESH_MAPPING_TBL;

CREATE OR REPLACE PROCEDURE           TOOL_PMO_REFRESH_MAPPING_TBL IS

/******************************************************************************
   NAME:       TOOL_PMO_REFRESH_MAPPING_TBL
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        11/13/2009   Chao Yu        1. Created this procedure.

   NOTES:

   Refresh UTI_TEMP_PMO_TO_MAPPING; table data.
   CEXEC team can run it to refresh data from task order table to see all editable
   task orders before or after update C_PMO_MIS_TO_NUM field.
******************************************************************************/
BEGIN
   
   delete from UTI_TEMP_PMO_TO_MAPPING;
   commit;
   
   
   insert into UTI_TEMP_PMO_TO_MAPPING 
     (N_TASK_ORDER_ID, C_TASK_ORDER_NUMBER, C_TASK_ORDER_TITLE, C_PMO_MIS_TO_NUM,  
      N_STATE_NUMBER, N_STATUS_NUMBER, N_OWNERSHIP_NUMBER, UPDATED_DATE)
   select distinct a.N_TASK_ORDER_ID, a.C_TASK_ORDER_NUMBER, a.C_TASK_ORDER_TITLE, a.C_PMO_MIS_TO_NUM,    
          a.N_STATE_NUMBER, a.N_STATUS_NUMBER, a.N_OWNERSHIP_NUMBER, sysdate as UPDATED_DATE
     from task_order a, sub_task_order b 
    where a.N_STATE_NUMBER in ( 101,102,105)
      and a.N_TASK_ORDER_REVISION = 0
      and a.N_TASK_ORDER_ID = b.N_TASK_ORDER_ID
 order by a.C_TASK_ORDER_NUMBER;
 
    commit;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END ; 
/
