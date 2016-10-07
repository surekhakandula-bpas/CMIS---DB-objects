DROP PROCEDURE TOOL_PMO_UPDATE_PMO_TO_NUM;

CREATE OR REPLACE PROCEDURE           TOOL_PMO_UPDATE_PMO_TO_NUM IS

/******************************************************************************
   NAME:       TOOL_PMO_UPDATE_PMO_TO_NUM
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        11/13/2009   Chao Yu       1. Created this procedure.

   NOTES:

   CEXEC team can run this stored procedure to update PMO TASK ORDER NUMBER.
   
   1) Run stored procedure TOOL_PMO_REFRESH_MAPPING_TBL to get all editable task orders
   2) Update the field C_PMO_MIS_TO_NUM in table UTI_TEMP_PMO_TO_MAPPING
   3) Run this stored procedure TOOL_PMO_UPDATE_PMO_TO_NUM to update task order table
   4) Run stored procedure TOOL_PMO_REFRESH_MAPPING_TBL again to verify the changes.
    
   
   CEXEC team can only update the C_PMO_MIS_TO_NUM for initial Draft,Eexcuted and Canceled task orders.
   Once task order is active, CEXEC can not change it anymore.
   C_PMO_MIS_TO_NUM data will be copied from previos revision to new revision when creating a new revision.
   
   Note: This stored procedure will update task order table for all records in which C_PMO_MIS_TO_NUM is not null 
   in UTI_TEMP_PMO_TO_MAPPING. YOu can only keep the records you want to update in UTI_TEMP_PMO_TO_MAPPING table.
    
******************************************************************************/

 ctr number;
 
BEGIN
   
    for p in (select N_TASK_ORDER_ID,C_PMO_MIS_TO_NUM 
                from UTI_TEMP_PMO_TO_MAPPING
               where C_PMO_MIS_TO_NUM is not null) loop
          
    
                  select count(*) into ctr
                    from task_order m, sub_task_order n 
                   where m.N_STATE_NUMBER in ( 101,102,105)
                     and m.N_TASK_ORDER_REVISION = 0
                     and m.N_TASK_ORDER_ID = n.N_TASK_ORDER_ID
                     and m.N_TASK_ORDER_ID =p.N_TASK_ORDER_ID; 
                     
                  if  ctr > 0 then
                     
                     update task_order
                        set C_PMO_MIS_TO_NUM = upper(trim(p.C_PMO_MIS_TO_NUM))
                       where N_TASK_ORDER_ID =p.N_TASK_ORDER_ID;
                       
                     commit;
                  
                  
                  end if;
               
     end loop;
     
      update task_order
         set C_PMO_MIS_TO_NUM = 'UNUSED'
       where C_PMO_MIS_TO_NUM is null
         and N_TASK_ORDER_ID in (
                    select N_TASK_ORDER_ID from task_order 
                     minus
                    select N_TASK_ORDER_ID from sub_task_order );
                     
      commit;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END; 
/
