DROP PACKAGE PK_WORKFLOW_HIST;

CREATE OR REPLACE PACKAGE PK_WORKFLOW_HIST AS

/* TODO enter package declarations (types, exceptions, methods etc) here */

PROCEDURE REPORT_USER_LOG ( P_RET_CODE OUT NUMBER,
                            P_MESSAGE  OUT VARCHAR2);
PROCEDURE REPORT_USER_LOG;

END PK_WORKFLOW_HIST;
/

DROP PACKAGE BODY PK_WORKFLOW_HIST;

CREATE OR REPLACE PACKAGE BODY            PK_WORKFLOW_HIST
AS
PROCEDURE REPORT_USER_LOG(
    P_RET_CODE OUT NUMBER,
    P_MESSAGE OUT VARCHAR2)
IS
  CURSOR cur_session_log
  IS
    SELECT N_USER_PROFILE_ID,
      N_TASK_ORDER_ID,
      C_USER_ROLE,
      N_OLD_OWNERSHIP_NUMBER,
      N_NEW_OWNERSHIP_NUMBER,
      C_ACTION,
      START_DATE_TIME,
      END_DATE_TIME
    FROM kitt_nisc3.V_PQ_TASK_ORDER_WF_HIST
    ORDER BY N_TASK_ORDER_ID,
      END_DATE_TIME;
  v_log_rec cur_session_log%rowtype;
  v_prev_log_rec cur_session_log%rowtype;
  v_prev_n_user_profile_id NUMBER;
  v_prev_end_date_time DATE;
  v_min_start_date_time DATE;
  v_max_end_date_time DATE;
  v_user_seq VARCHAR2(1) := 'N';
BEGIN
  /* TODO implementation required */
  P_RET_CODE := 0;
  P_MESSAGE  := 'SUCCESS';
  EXECUTE immediate 'truncate table workflow_history';
  v_min_start_date_time  := systimestamp;
  v_max_end_date_time := systimestamp;
  FOR v_log_rec  IN cur_session_log
  LOOP
    IF v_log_rec.n_user_profile_id||v_log_rec.n_task_order_id != v_prev_log_rec.n_user_profile_id ||v_prev_log_rec.n_task_order_id THEN
      INSERT
      INTO workflow_history
        (
          N_TASK_ORDER_ID,
          N_USER_PROFILE_ID,
          C_USER_ROLE,
          N_OLD_OWNERSHIP_NUMBER,
          N_NEW_OWNERSHIP_NUMBER,
          C_ACTION,
          START_DATE_TIME,
          END_DATE_TIME
        )
        VALUES
        (
          v_prev_log_rec.n_task_order_id,
          v_prev_log_rec.n_user_profile_id,
          v_prev_log_rec.c_user_role,
          v_prev_log_rec.N_OLD_OWNERSHIP_NUMBER,
          v_prev_log_rec.N_NEW_OWNERSHIP_NUMBER,
          v_prev_log_rec.c_action,
          -- v_prev_log_rec.time_in,
          DECODE(v_user_seq ,'N' , v_prev_log_rec.start_date_time ,v_min_start_date_time),
          v_prev_log_rec.end_date_time
        );
      v_user_seq            := 'N';
      v_min_start_date_time := v_log_rec.start_date_time;
    ELSE
      v_user_seq := 'Y';
     -- dbms_output.put_line      (        'Inside same user'      )      ;
      IF v_log_rec.start_date_time < v_min_start_date_time THEN
        v_min_start_date_time     := v_log_rec.start_date_time;
      END IF;
    END IF;
    v_prev_log_rec := v_log_rec;
  END LOOP;
  dbms_output.put_line
  (
    'outside end of cursor'
  )
  ;
  INSERT
  INTO WORKFLOW_HISTORY
    (
      N_TASK_ORDER_ID,
      N_USER_PROFILE_ID,
      C_USER_ROLE,
      N_OLD_OWNERSHIP_NUMBER,
      N_NEW_OWNERSHIP_NUMBER,
      C_ACTION,
      START_DATE_TIME,
      END_DATE_TIME
    )
    VALUES
    (
      v_prev_log_rec.n_task_order_id,
      v_prev_log_rec.n_user_profile_id,
      v_prev_log_rec.c_user_role,
      v_prev_log_rec.N_OLD_OWNERSHIP_NUMBER,
      v_prev_log_rec.N_NEW_OWNERSHIP_NUMBER,
      v_prev_log_rec.c_action,
      v_prev_log_rec.start_date_time,
      v_prev_log_rec.end_date_time
    );
  COMMIT;
END REPORT_USER_LOG;

PROCEDURE REPORT_USER_LOG
IS
                X NUMBER;
                Y VARCHAR2(10);
BEGIN
                REPORT_USER_LOG(X,Y);
END REPORT_USER_LOG;

END PK_WORKFLOW_HIST;
/
