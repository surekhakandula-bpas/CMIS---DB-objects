DROP PROCEDURE CLOSE_TASK_ORDER;

CREATE OR REPLACE PROCEDURE            CLOSE_TASK_ORDER(status_out OUT VARCHAR2) AS
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
   3.0       03/02/2010   David Dixon-Peugh 3. Closed tasks should be "Pending Closeout"
   4.0       06/03/2010   Chao Yu           4. Not set Pending Closeout" for canceled sub task order
   4.1      04/13/2011  Jon Goff      1.  Added final exception

******************************************************************************/

new_to_id     number(9) :=0;
funded_to_id  number(9) :=0;
Msg           VARCHAR2(200);
ctr           NUMBER(9) :=0;
ctr2          NUMBER(9) :=0;
subids        NUMBER(9) :=0;
lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

BEGIN


-- Get Task Orders in Active state then get all subtasks, check whether subtasks should close then check whether
-- task order should close.
  BEGIN
  SELECT count(*) into ctr
    from task_order t, state s--, status st
    Where s.c_state_label = 'Active'
      and s.n_state_number = t.n_state_number;
      --and sysdate > t.d_pop_end_date;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         Msg:='No active task orders found'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
         dbms_output.put_line(Msg);
         status_out := Msg;
      WHEN OTHERS THEN
         Msg:='Error:Select count of active task orders: ' || new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
         dbms_output.put_line(Msg);
         status_out := Msg;
         RAISE;
     END;
     dbms_output.put_line('before for, ctr: ' || ctr);
IF ctr > 0 then
  -- Get subtasks beyond end date
  FOR subtasks IN
    (SELECT s.n_sub_task_order_id --into subid
     FROM sub_task_order s, task_order t, state st
     WHERE s.n_task_order_id = t.n_task_order_id
      and st.c_state_label = 'Active'
      and st.n_state_number = t.n_state_number
      and s.n_state_number is null
      and s.N_STATUS_NUMBER > 0 -- handle canceled sub task order
      and sysdate > s.d_sub_task_order_end_date + 1)

      LOOP
        dbms_output.put_line('up to subtask id: ' || subtasks.n_sub_task_order_id);
        BEGIN
          UPDATE sub_task_order
          SET N_STATE_NUMBER =  (Select N_state_number from state where C_state_label = 'Closed')
              , N_STATUS_NUMBER = 500 -- Pending Closeout
          WHERE n_sub_task_order_id = subtasks.n_sub_task_order_id;

          EXCEPTION
            WHEN NO_DATA_FOUND THEN
               Msg:='No subtask order found to update'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
               dbms_output.put_line(Msg);
            WHEN OTHERS THEN
               Msg:='Error: Update to closed of subtask order failed: ' || subtasks.n_sub_task_order_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
               dbms_output.put_line(Msg);
               RAISE;
        END;
        subids := subids + 1;
      END LOOP;
  -- Update task order records to closed state
  dbms_output.put_line('in for, ctr: ' || ctr);
  FOR taskorders IN

    (SELECT t.n_task_order_id --into new_to_id
    from task_order t, state s--, status st
    Where s.c_state_label = 'Active'
      and s.n_state_number = t.n_state_number
      and sysdate > t.d_pop_end_date + 1)

         LOOP
         dbms_output.put_line('up to tos: ' ||taskorders.n_task_order_id);

              BEGIN
                UPDATE task_order
                SET N_STATE_NUMBER =  (Select N_state_number from state where C_state_label = 'Closed'),
                  N_STATUS_NUMBER = 500, -- Pending Closeout
                  d_inactive_date = sysdate,
                  n_ownership_number = 500  -- TOM ownership for Closeout
                WHERE n_task_order_id = taskorders.n_task_order_id;

                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='No task order found to update'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     Msg:='Error: Update to closed of active task order failed: ' || taskorders.n_task_order_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                     RAISE;
                END;
              --END IF;

            /*EXCEPTION
                WHEN NO_DATA_FOUND THEN
                   Msg:='No funded task order found'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                   dbms_output.put_line(Msg);
                WHEN OTHERS THEN
                   Msg:='Error: Count of funded executed task orders: ' || new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                   dbms_output.put_line(Msg);
                Rollback;
          End; */
          ctr2 := ctr2 + 1;
        End loop;
        commit;
        If ctr2 != ctr then
          dbms_output.put_line(ctr ||' Records found but ' || ctr2 ||' records updated.');
          ctr := ctr2;
        End If;
        status_out := 'Successful, SubTasks updated to Closed: '||subids|| ', Task Order Records updated to Closed: '||ctr;

ELSE
  status_out := 'No records found to close';
End IF;

BEGIN
      INSERT INTO Scheduled_task_log (n_schedule_task_log_id, c_action_label, c_description, d_task_date)
      values (seq_scheduled_task_log.nextval, 'Close Task Orders', status_out, sysdate);

EXCEPTION
            WHEN OTHERS THEN
            Msg:='Error: Count of active task orders: ' || new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
            dbms_output.put_line(Msg);
            Rollback;
End;



EXCEPTION
    WHEN OTHERS THEN

          ROLLBACK;
          lv_msg :=  SQLERRM || ' '|| status_out||' '|| Msg;

          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'CLOSE TASK ORDER',
          NULL,
          'ERROR',
          'Error processing Close Task Order.',
           lv_msg,
          NULL,
          SYSDATE
           );
       COMMIT;


END CLOSE_TASK_ORDER;
/
