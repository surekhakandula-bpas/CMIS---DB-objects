DROP PROCEDURE TOOL_SET_SUBTO_STATUS;

CREATE OR REPLACE PROCEDURE TOOL_SET_SUBTO_STATUS IS

MyStateNum number;
MySubStatusNum number;

BEGIN
   
    for c in (select a.N_SUB_TASK_ORDER_ID, a.N_TASK_ORDER_ID 
                from SUB_TASK_ORDER a 
               where a.N_STATUS_NUMBER = 100) loop
    
    
          select n_state_number into MyStateNum from task_order where N_TASK_ORDER_ID = c.N_TASK_ORDER_ID;
          
          if  MyStateNum = 101 then
             MySubStatusNum:= 101;
          elsif MyStateNum = 103 then
             MySubStatusNum:= 100;
          elsif MyStateNum = 107 then
             MySubStatusNum:= 107;
          elsif MyStateNum = 104 then
             MySubStatusNum:= 500;
          elsif MyStateNum = 105 then
             MySubStatusNum:= -100;
          end if;
          
          update sub_task_order set N_STATUS_NUMBER = MySubStatusNum where N_SUB_TASK_ORDER_ID = c.N_SUB_TASK_ORDER_ID;
    
    end loop;
    
    commit;
    
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_SET_SUBTO_STATUS; 
/
