DROP PROCEDURE TOOL_SETUP_BASE_NUM;

CREATE OR REPLACE PROCEDURE                TOOL_SETUP_BASE_NUM IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       TOOL_SETUP_BASE_NUM
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        6/23/2010   Chao Yu       1. Created this procedure.

   NOTES:


******************************************************************************/


 
BEGIN
   
   
    update ALLOCATION a
    set a.C_SUB_TASK_ORDER_NAME = ( select b.C_SUB_TASK_ORDER_NAME 
                                      from V_TOOL_GET_BASE_NUM b
                                     where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID),
        a.N_TASK_ORDER_BASE_ID = ( select b.BASE_NUM
                                     from V_TOOL_GET_BASE_NUM b
                                    where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID );
    
    update INVOICE_ITEM a
    set a.C_SUB_TASK_ORDER_NAME = ( select b.C_SUB_TASK_ORDER_NAME 
                                      from V_TOOL_GET_BASE_NUM b
                                     where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID),
        a.N_TASK_ORDER_BASE_ID = ( select b.BASE_NUM
                                     from V_TOOL_GET_BASE_NUM b
                                    where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID );
     
    
    update PAYMENT_INSTRUCTION_ITEM a
      set a.C_SUB_TASK_ORDER_NAME = ( select b.C_SUB_TASK_ORDER_NAME 
                                   from V_TOOL_GET_BASE_NUM b
                                  where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID),
         a.N_TASK_ORDER_BASE_ID = ( select b.BASE_NUM
                                  from V_TOOL_GET_BASE_NUM b
                                 where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID );
    update SUB_TASK_ORDER a
      set  a.N_TASK_ORDER_BASE_ID = ( select b.BASE_NUM
                                  from V_TOOL_GET_BASE_NUM b
                                 where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID );
                                 
    update TASK_ORDER 
       set  N_TASK_ORDER_BASE_ID = substr(c_task_order_number, 1, length(c_task_order_number)-3); 
       
    update INVOICE_LOAD_AUDIT a
    set a.C_SUB_TASK_ORDER_NAME = ( select b.C_SUB_TASK_ORDER_NAME 
                                      from V_TOOL_GET_BASE_NUM b
                                     where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID),
        a.N_TASK_ORDER_BASE_ID = ( select b.BASE_NUM
                                     from V_TOOL_GET_BASE_NUM b
                                    where b.N_SUB_TASK_ORDER_ID = a.N_SUB_TASK_ORDER_ID );

                                                                   
  Commit;
  
  
  
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_SETUP_BASE_NUM; 
/
