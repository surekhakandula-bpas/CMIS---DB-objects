DROP PROCEDURE ACTIVATE_TASK_ORDER;

CREATE OR REPLACE PROCEDURE            ACTIVATE_TASK_ORDER(status_out OUT VARCHAR2) AS
/******************************************************************************
   NAME:       Activate_Task_Order
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        1/22/2009   Cliff Baumen      1. Created this procedure.
   1.1        6/07/2010   Jon Goff        1. Modified to allow single task order activation
   1.2        04/13/2011  Jon Goff      1.  Added final exception

   Procedure scheduled to run daily setting state to active for any task order meeting
   conditions.

******************************************************************************/

Msg           VARCHAR2(200);
fee           char(1);
subname       varchar2(14);
new_status    varchar2(30);
new_to_id     number(9) :=0;
funded_to_id  number(9) :=0;
ctr           NUMBER(9);
ctr2          NUMBER(9);
alloc_amt     number(14,3);
delphi_id     number(9);
remaining     number(14,3);
lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

BEGIN


-- Get Task Orders in Executed state
  BEGIN
    SELECT count(*) into ctr
      FROM task_order t, state s--, status st
     WHERE s.c_state_label = 'Executed'
      --and (st.c_status_label = 'CO Signed' OR st.c_status_label = 'Approved')  -- need confirmation
     -- and st.n_status_number = t.n_status_number
       AND s.n_state_number = t.n_state_number
       AND sysdate >= t.d_pop_start_date and sysdate <= t.d_pop_end_date;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
       Msg:='No executed task order found'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
       dbms_output.put_line(Msg);
       status_out := Msg;
    WHEN OTHERS THEN
       Msg:='Error:Select of executed task orders: ' || new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
       dbms_output.put_line(Msg);
       status_out := Msg;
        RAISE;
  END;

  dbms_output.put_line('before for, ctr: ' || ctr);
  IF ctr > 0 THEN

    dbms_output.put_line('in for, ctr: ' || ctr);
    FOR taskorders IN
      ( SELECT t.n_task_order_id --into new_to_id
          FROM task_order t, state s--, status st
         WHERE s.c_state_label = 'Executed'
         --and (st.c_status_label = 'CO Signed' OR st.c_status_label = 'Approved')  -- need confirmation
         --and st.n_status_number = t.n_status_number
           AND s.n_state_number = t.n_state_number
           AND sysdate >= t.d_pop_start_date) --and sysdate <= t.d_pop_end_date)

    LOOP
        ACTIVATE_SINGLE_TASK_ORDER(taskorders.n_task_order_id, status_out);
        IF status_out != 'Successful' THEN
            dbms_output.put_line('Errors with attempting to activate task order '||to_char(taskorders.n_task_order_id)||'.  '||status_out);
        END IF;
    END LOOP;

    COMMIT;
    status_out := 'Successful, Records updated to Active: '||ctr;

  ELSE
    status_out := 'No records found to activate';
  END IF;


  BEGIN
    INSERT INTO Scheduled_task_log (n_schedule_task_log_id, c_action_label, c_description, d_task_date)
      values (seq_scheduled_task_log.nextval, 'Activate Task Orders', status_out, sysdate);

  EXCEPTION
    WHEN OTHERS THEN
      Msg:='Error: Count of funded executed task orders: ' || new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
      status_out := Msg;
      dbms_output.put_line(Msg);
      RAISE;
  END;


EXCEPTION
       WHEN OTHERS THEN

          status_out:='Error: ACTIVATE TASK ORDER ' || to_char(SQLCODE) ||'-'||SQLERRM;
          dbms_output.put_line(status_out);

          ROLLBACK;
          lv_msg :=  SQLERRM || ' '|| status_out;

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
          'ACTIVATE TASK ORDER',
          NULL,
          'ERROR',
          'Error processing Activate Task Order.',
           lv_msg,
          NULL,
          SYSDATE
           );

       COMMIT;

END ACTIVATE_TASK_ORDER;
/
