DROP PROCEDURE CLOSE_TASK_ORDER_DISABLED;

CREATE OR REPLACE PROCEDURE           CLOSE_TASK_ORDER_DISABLED(status_out OUT VARCHAR2) AS
/******************************************************************************
   NAME:       Close_Task_Order
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/13/2009   Cliff Baumen      1. Created this procedure.
   Procedure scheduled to run daily setting state to close for any task order meeting
   conditions.
   2.0       ~9/2/2009 on Cliff Baumen      2. Update for close out, update ownership
   and add closing of subtasks.

******************************************************************************/

new_to_id     number(9) :=0;
funded_to_id  number(9) :=0;
Msg           VARCHAR2(200);
ctr           NUMBER(9) :=0;
ctr2          NUMBER(9) :=0;
subids        NUMBER(9) :=0;
BEGIN


status_out := 'Close task order action has been disabled.';
BEGIN
      INSERT INTO Scheduled_task_log (n_schedule_task_log_id, c_action_label, c_description, d_task_date)
      values (seq_scheduled_task_log.nextval, 'Close Task Orders', status_out, sysdate);
      
      EXCEPTION 
            WHEN OTHERS THEN
               Msg:='Error: Count of active task orders: ' || new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
               dbms_output.put_line(Msg);
            Rollback;
      End;

END; 
/
