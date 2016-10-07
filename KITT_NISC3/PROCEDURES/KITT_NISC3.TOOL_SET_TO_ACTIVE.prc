DROP PROCEDURE TOOL_SET_TO_ACTIVE;

CREATE OR REPLACE PROCEDURE           TOOL_SET_TO_ACTIVE IS

/******************************************************************************
   NAME:       TOOL_SET_TO_ACTIVE 
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        6/6/2009          1. Created this procedure.

   NOTES:

    Active specific task order to skip the approval steps.

******************************************************************************/

Msg varchar2 (200);

BEGIN

   /*
   
     Only update the task order state and activate them by running the sceduled 
     procedure ACTIVATE_TASK_ORDER(Msg) at night time.
     
   */
   for c in ( select N_TASK_ORDER_ID,
                     N_STATE_NUMBER,
                     N_OWNERSHIP_NUMBER, 
                     N_TASK_ORDER_REVISION, 
                     N_PREVIOUS_TASK_ORDER_ID, 
                     D_POP_START_DATE, 
                     D_POP_END_DATE, 
                     D_ACTIVE_DATE, 
                     D_INACTIVE_DATE  
                from V_TOOL_SET_TO_ACTIVE
                order by N_TASK_ORDER_ID ) loop
                
          update TASK_ORDER  
             set N_STATE_NUMBER =102,
                 N_OWNERSHIP_NUMBER = 110
           where N_TASK_ORDER_ID =c.N_TASK_ORDER_ID;        
                
   end loop;

   commit;
   
   
   /*
   for c in ( select N_TASK_ORDER_ID,
                     N_STATE_NUMBER,
                     N_OWNERSHIP_NUMBER, 
                     N_TASK_ORDER_REVISION, 
                     N_PREVIOUS_TASK_ORDER_ID, 
                     D_POP_START_DATE, 
                     D_POP_END_DATE, 
                     D_ACTIVE_DATE, 
                     D_INACTIVE_DATE  
                from V_TOOL_SET_TO_ACTIVE
                order by N_TASK_ORDER_ID ) loop
                
       
       if c.N_TASK_ORDER_REVISION = 0 then

          update TASK_ORDER  
             set N_STATE_NUMBER =103,
                 N_OWNERSHIP_NUMBER = 110,
                 D_ACTIVE_DATE = D_POP_START_DATE
           where N_TASK_ORDER_ID =c.N_TASK_ORDER_ID;
    
       else
         
           update TASK_ORDER  
              set N_STATE_NUMBER =102,
                  N_OWNERSHIP_NUMBER = 110,
                  D_ACTIVE_DATE = sysdate
            where N_TASK_ORDER_ID =c.N_TASK_ORDER_ID;
    
           update TASK_ORDER  
              set N_STATE_NUMBER =107,
                  N_OWNERSHIP_NUMBER = 110,
                  D_INACTIVE_DATE = sysdate
            where N_TASK_ORDER_ID =c.N_PREVIOUS_TASK_ORDER_ID;
            
           

            
       end if;
       
   end loop;
    
   commit;
   
   ACTIVATE_TASK_ORDER(Msg);
    */
  
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END ; 
/
