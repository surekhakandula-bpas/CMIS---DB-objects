DROP PROCEDURE CREATE_REVISION;

CREATE OR REPLACE PROCEDURE            "CREATE_REVISION" (to_id IN NUMBER , created_id IN NUMBER , user_role IN VARCHAR2, status_out OUT VARCHAR2, return_new_to OUT NUMBER) AS
/******************************************************************************
   NAME:       Create_Revision
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        11/7/2008   Cliff Baumen      1. Created this procedure.
   2.0        3/16/2010   David Dixon-Peugh 2. Modified to manage the AETO_TASK_ORDER table.
   3.0          10/07/2010 JGOFF        1.   added reference for N_TASK_ORDER_BASE_ID
   3.1          12/15/2010 JGOFF        1.   Excluded obsolete column EXTENDED_ELEMENT.N_ELEMENT_NUMBER
                                                    2. Renamed references for new columns CB_SOO_TEXT, CB_PWS_TEXT
   4.0        1/13/2011   RYU                 Fixed Deliverable SQL error
   4.1        1/13/2011   RYU                 NISCIII-253 Remove N_POC_ID from SUB_TASK_ORDER table
   4.2        04/13/2011  Jon Goff      1.  Added final exception
   4.3        05/20/2011  Jon Goff      1.  AETOs are not carried over when new TO Revisions are created
   4.4        06/15/2011  Kyle Binns    1.  Fixed to only match on exact task order base numbers (not 1, 10, 11, 100...)
   4.5        09/01/2011  Jon Goff      1. Remove the GTI assignment for this procedure. r1.4 requirement
   4.5        11/28/2011  Jon Goff      1. Removed carryover comments
******************************************************************************/
ctr             NUMBER(9);
to_start        NUMBER(9);
to_end          NUMBER(9);
r_number        NUMBER(9);
revisions       NUMBER(9);
to_lnumber      VARCHAR2(3);
new_tonumber    VARCHAR2(10);
new_sub_to_id   number(9);
to_postfix    number(9);
to_baseid    number(9);
initial_status  number(9) := 101;
initial_state   number(9) := 101;
initial_owner   number(9) := 101;
new_attach_id   number(9);
new_trans_id    number(9);
revision_state  VARCHAR2(25);
states          number(9);
hold_tonumber   VARCHAR2(10);
--return_new_to   number(9) := 0;
Msg VARCHAR2(200);

new_to_id varchar2(10);
lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

BEGIN

-- Determine if Task Order available for Revision
status_out := 'Unsuccessful';
return_new_to := 0;
Select count(*) into ctr
From task_order t, state s
Where n_task_order_id = to_id --task_order_id
  And t.n_state_number = s.n_state_number
  And c_state_label IN ('Active');

IF ctr = 1 then  -- Ensure no current revision. get first and last part of to number.

    Select n_task_order_revision, n_task_order_base_id
    into r_number, to_baseid
    From task_order where n_task_order_id = to_id; -- task_order_id

   Select max(n_task_order_revision) into revisions
   From task_order where n_task_order_base_id = to_baseid;
   dbms_output.PUT_LINE('max revision: ' || revisions);
   dbms_output.PUT_LINE('TO to use: ' ||to_id || '.' || revisions);

   -- Get state of max revision so can check for a cancelled revision and reuse the task order number
   IF revisions < 10 then
      hold_tonumber := to_baseid || '.0' || revisions;
   ELSE
      hold_tonumber := to_baseid || '.' || revisions;
  END IF;

   -- Ensure that no other task order numbers have a currrent revision.
   Select count(*) into ctr from task_order t, state s
    where t.n_task_order_base_id = to_char(to_baseid)
      and t.n_task_order_revision != r_number
      and s.n_state_number = t.n_state_number
      and s.c_state_label IN ('Draft','Executed');
    dbms_output.PUT_LINE('ctr: ' || ctr || ' r_number: ' || r_number || ' hold_tonumber: ' || hold_tonumber);

      IF ctr = 0 THEN

        /*Select distinct s.c_state_label into revision_state
        From task_order t, state s
        Where t.n_state_number = s.n_state_number
        and t.c_task_order_number = hold_tonumber;*/

        Select count(*) into states
        From task_order t, state s
        Where t.n_state_number = s.n_state_number
        and t.c_task_order_number = hold_tonumber
        and s.c_state_label='Active';

         IF states > 0 THEN
          revisions := revisions + 1;
         END IF;

        -- Qualifies for revision - add 1 to revision (unless cancelled found) and create new task order
        to_postfix := revisions;
        dbms_output.PUT_LINE('to_postfix: ' ||to_postfix);
        IF to_postfix < 10 then
          new_tonumber := to_baseid || '.0' || to_postfix;
        ELSE
          new_tonumber := to_baseid || '.' || to_postfix;
        END IF;
        dbms_output.PUT_LINE('newtonumber: ' ||new_tonumber);
        dbms_output.PUT_LINE('revisions: ' ||revisions);

       SET TRANSACTION READ WRITE NAME 'dotaskorder';

        BEGIN

        SELECT seq_task_order.nextval into new_to_id from dual;
          INSERT INTO task_order (N_CONTRACT_ID, N_TASK_ORDER_ID, N_TASK_ORDER_BASE_ID, N_TASK_ORDER_REVISION, N_PREVIOUS_TASK_ORDER_ID,
            C_TASK_ORDER_NUMBER, C_TASK_ORDER_TITLE, N_FUNDING_TYPE_ID, CB_SOO_TEXT, CB_PWS_TEXT, D_POP_START_DATE,
            D_POP_END_DATE, N_ETO_ID, N_TOTAL_ODC_ESTIMATE_VALUE, N_TOTAL_TRAVEL_ESTIMATE_VALUE,
            N_TOTAL_SKILL_TYPE_EST_VALUE, N_TASK_ORDER_ESTIMATE_VALUE, N_TASK_ORDER_COST_VALUE, N_TOM_ID,
            N_TOTAL_LABOR_AMOUNT, N_TOTAL_LABOR_HOURS, N_TOTAL_TRAVEL_AMOUNT, N_TOTAL_ODC_AMOUNT,
            N_STATUS_NUMBER, N_STATE_NUMBER, N_OWNERSHIP_NUMBER, C_PMO_TASK_ORDER, F_TASK_ORDER_LOCKED,
            N_LOCKED_BY_ID, D_LOCKED_TS, N_CREATED_BY_ID, D_REC_VERSION, D_CLOSE_OUT_DAY,
           D_ANTICIPATED_CLOSE_OUT_DATE, F_MIX_FUNDS, D_ESTIMATE_DATE, c_pmo_mis_to_num)
          SELECT N_CONTRACT_ID,
            new_to_id,
            N_TASK_ORDER_BASE_ID,
            revisions,
            to_id,
            new_tonumber,
            C_TASK_ORDER_TITLE,
            N_FUNDING_TYPE_ID,
            cb_SOO_TEXT,
            cb_pws_text,
            D_POP_START_DATE,
            D_POP_END_DATE,
            N_ETO_ID,
            N_TOTAL_ODC_ESTIMATE_VALUE,
            N_TOTAL_TRAVEL_ESTIMATE_VALUE,
            n_total_skill_type_est_value,
            N_TASK_ORDER_ESTIMATE_VALUE,
            N_TASK_ORDER_COST_VALUE,
            N_TOM_ID,
            n_total_labor_amount,
            n_total_labor_hours,
            n_total_travel_amount,
            n_total_odc_amount,
            initial_status,
            initial_state,
            initial_owner,
            C_PMO_TASK_ORDER,
            null,
            null,
            null,
            created_id,
            sysdate,
            D_CLOSE_OUT_DAY,
            D_ANTICIPATED_CLOSE_OUT_DATE,
            F_MIX_FUNDS,
            D_ESTIMATE_DATE,
            C_PMO_MIS_TO_NUM
          FROM task_order
          WHERE n_task_order_id = to_id;


        EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='The task order '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 status_out:='Error:insert of task order record: ' ||  to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(status_out);
                 RAISE;
        END;
        -- Manage the AETO_TASK_ORDER table.


       BEGIN
        INSERT INTO AETO_TASK_ORDER (N_AETO_ID, N_TASK_ORDER_ID)
        SELECT N_AETO_ID, new_to_id
        FROM AETO_TASK_ORDER
        WHERE N_TASK_ORDER_ID = to_id;

        EXCEPTION
            WHEN OTHERS THEN
               status_out:='Error:insert to aeto task order table: ' ||  to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
               dbms_output.put_line(status_out);
                RAISE;
       END;


       --dbms_output.put_line('about to do sub task for loop for ');
       -- copy all sub tasks from original task order
       FOR sub IN
          (Select n_sub_task_order_id From sub_task_order where n_task_order_id = to_id)
          LOOP
         dbms_output.put_line('up to sub task using to: ' || new_to_id);
         BEGIN
          SELECT seq_sub_task_order.nextval into new_sub_to_id from dual;
          dbms_output.put_line('up to new sub task using: ' || new_sub_to_id);
          INSERT INTO SUB_TASK_ORDER (N_SUB_TASK_ORDER_ID, N_TASK_ORDER_ID, N_TASK_ORDER_BASE_ID, C_SUB_TASK_ORDER_NAME,
            C_SUB_TASK_ORDER_TITLE, D_SUB_TASK_ORDER_START_DATE, D_SUB_TASK_ORDER_END_DATE, N_DAYS,
            N_TOTAL_ESTIMATE_DOLLAR_AMOUNT, N_TOTAL_ESTIMATE_HOURS, N_ODC_COST_ESTIMATE, N_TRAVEL_COST_ESTIMATE,
            N_STATUS_NUMBER, N_TOTAL_LABOR_HOURS, N_TOTAL_LABOR_AMOUNT, N_TOTAL_TRAVEL_AMOUNT, N_TOTAL_ODC_AMOUNT,
            N_SUB_TASK_ORDER_COST, D_REC_VERSION, N_SKILL_TYPE_COST_ESTIMATE, T_COMMENT)
            SELECT new_sub_to_id,
              new_to_id,
              N_TASK_ORDER_BASE_ID,
              c_sub_task_order_name,
              C_SUB_TASK_ORDER_TITLE,
              D_SUB_TASK_ORDER_START_DATE,
              D_SUB_TASK_ORDER_END_DATE,
              N_DAYS,
              N_TOTAL_ESTIMATE_DOLLAR_AMOUNT,
              N_TOTAL_ESTIMATE_HOURS,
              N_ODC_COST_ESTIMATE,
              N_TRAVEL_COST_ESTIMATE,
              N_STATUS_NUMBER,
              N_TOTAL_LABOR_HOURS,
              N_TOTAL_LABOR_AMOUNT,
              N_TOTAL_TRAVEL_AMOUNT,
              N_TOTAL_ODC_AMOUNT,
              N_SUB_TASK_ORDER_COST,
              sysdate,
              N_SKILL_TYPE_COST_ESTIMATE,
              NULL
            FROM Sub_task_order
            WHERE n_sub_task_order_id = sub.n_sub_task_order_id;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                   Msg:='The subtask order insert found no recs from task order:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                   dbms_output.put_line(Msg);
                WHEN OTHERS THEN
                   status_out:='Error:sub task:' ||  to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                   dbms_output.put_line(status_out);
                  RAISE;
          END;
          dbms_output.put_line('sub is: ' || sub.n_sub_task_order_id);
              -- Copy tables based on sub task order id
              -- Copy travel_cost
               FOR travel In
                (Select n_travel_cost_id From travel_cost where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to travel cost');
                BEGIN
                SELECT seq_travel_cost.nextval into new_attach_id from dual;
                INSERT INTO travel_cost (N_TRAVEL_COST_ID, N_SUB_TASK_ORDER_ID, N_TRIP, N_COST_PER_TRIP, N_TOTAL_COST)
                  SELECT new_attach_id,
                    new_sub_to_id,
                    n_trip,
                    n_cost_per_trip,
                    n_total_cost
                  FROM travel_cost
                  WHERE n_travel_cost_id = travel.n_travel_cost_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Travel cost found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:travel cost for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                     RAISE;
                END;
              End loop;
               -- Copy sub_task_skill_type
               FOR skill IN
                (Select n_skill_type_id From sub_task_skill_type where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to skill type, current sub is: ' || new_sub_to_id);
                BEGIN
                --SELECT seq_sub_task_order_skill_type.nextval into new_attach_id from dual;
                --dbms_output.put_line('new sub id skill type is: ' || new_attach_id);
                INSERT INTO sub_task_skill_type (N_SUB_TASK_ORDER_ID, N_SKILL_TYPE_ID, N_SKILL_TYPE_FTE,
                  N_SKILL_TYPE_HOURS, N_SKILL_TYPE_COST, n_skill_type_rate)
                  SELECT new_sub_to_id,
                    n_skill_type_id,
                    n_skill_type_fte,
                    n_skill_type_hours,
                    n_skill_type_cost,
                    n_skill_type_rate
                  FROM sub_task_skill_type
                  WHERE n_sub_task_order_id = sub.n_sub_task_order_id
                    and n_skill_type_id = skill.n_skill_type_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Skill type found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:Skill type for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                     RAISE;
                END;
              End loop;
              -- Copy sub_task_labor_category
               FOR labor IN
                (Select n_sub_task_labor_category_id From sub_task_labor_category where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to sub_task_labor_category');
                BEGIN
                SELECT seq_sub_task_labor_category.nextval into new_attach_id from dual;
                INSERT INTO sub_task_labor_category (N_SUB_TASK_ORDER_ID, N_LABOR_CATEGORY_ID, C_LEVEL,
                  N_SKILL_TYPE_ID, N_LABOR_CATEGORY_HOURS, N_LABOR_CATEGORY_RATE, N_LABOR_CATEGORY_VALUE,
                  N_FTE, N_HOURS, T_COMMENTS, n_sub_task_labor_category_id, c_ss_title, CB_SS_Description)
                  SELECT new_sub_to_id,
                    n_labor_category_id,
                    c_level,
                    n_skill_type_id,
                    n_labor_category_hours,
                    n_labor_category_rate,
                    n_labor_category_value,
                    n_fte,
                    n_hours,
                    t_comments,
                    new_attach_id,
                    c_ss_title,
                    CB_SS_Description
                  FROM sub_task_labor_category
                  WHERE n_sub_task_order_id = sub.n_sub_task_order_id
                    and n_sub_task_labor_category_id = labor.n_sub_task_labor_category_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Sub_task Labor Category found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:Sub_task Labor Category for subtask:' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                     RAISE;
                END;
              End loop;
              -- Copy sub_task_functional_work_area
               FOR func IN
                (Select n_functional_work_area_id From sub_task_functional_work_area where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to sub_task_functional_work_area');
                BEGIN
                INSERT INTO sub_task_functional_work_area (N_SUB_TASK_ORDER_ID, N_FUNCTIONAL_WORK_AREA_ID)
                  SELECT new_sub_to_id,
                    n_functional_work_area_id
                  FROM sub_task_functional_work_area
                  WHERE n_sub_task_order_id = sub.n_sub_task_order_id
                    and n_functional_work_area_id = func.n_functional_work_area_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Functional Work area found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:Subtask functional work area for subtask:' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                      RAISE;
                END;
              End loop;


              -- Copy deliverable when subtask is not null
               FOR DELIVERABLE IN
                (Select n_deliverable_id From deliverable where n_task_order_base_id = to_id and
                  n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to deliverable in sub area');
                BEGIN
                SELECT SEQ_DELIVERABLE.NEXTVAL INTO NEW_ATTACH_ID FROM DUAL;
                INSERT INTO DELIVERABLE (N_DELIVERABLE_ID, N_TASK_ORDER_BASE_ID, N_SUB_TASK_ORDER_ID,
                  CB_DESCRIPTION, C_TYPE)
                  SELECT new_attach_id,
                    new_to_id,
                    NEW_SUB_TO_ID,
                    cb_description,
                    c_type
                  FROM deliverable
                  WHERE n_deliverable_id = deliverable.n_deliverable_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Deliverable in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:Deliverable in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                      RAISE;
                END;
              End loop;


            /*  -- Copy note_comment when subtask is not null
               FOR nc IN
                (Select n_note_id From note_comment where n_task_order_id = to_id and
                  n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to note_comment in sub area');
                BEGIN
                SELECT seq_note_comment.nextval into new_attach_id from dual;
                INSERT INTO note_comment (N_NOTE_ID, N_TASK_ORDER_ID, N_SUB_TASK_ORDER_ID, N_USER_PROFILE_ID,
                    D_NOTE_TS, T_COMMENT)
                  SELECT new_attach_id,
                    new_to_id,
                    new_sub_to_id,
                    n_user_profile_id,
                    sysdate,
                    t_comment
                  FROM note_comment
                  WHERE n_note_id = nc.n_note_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Note comment in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:Note comment in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                      RAISE;
                END;
              End loop;
            */

               -- Copy subtask_servicearea
               FOR stsa IN
                (Select n_service_area_id From subtask_servicearea where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to subtask servicearea in sub area');
                BEGIN
                INSERT INTO subtask_servicearea (n_sub_task_order_id, n_service_area_id)
                  SELECT new_sub_to_id,
                    n_service_area_id
                  FROM subtask_servicearea
                  WHERE n_service_area_id = stsa.n_service_area_id
                    and n_sub_task_order_id = sub.n_sub_task_order_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Subtask service area in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:subtask_service area in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                     RAISE;
                END;
              End loop;
              -- Copy allocation - for now do not include financial data CB 3/16/09
             /* FOR allo IN
                (Select n_allocation_id From allocation where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to allocation in sub area');
                BEGIN
                SELECT seq_allocation.nextval into new_attach_id from dual;
                INSERT INTO allocation (n_allocation_id, n_sub_task_order_id, n_user_profile_id, n_delphi_obligation_id,
                  n_eto_id, n_allocation_amount, n_deallocation_amount, d_allocation_date)
                  SELECT new_attach_id,
                    new_sub_to_id,
                    n_user_profile_id,
                    n_delphi_obligation_id,
                    n_eto_id,
                    n_allocation_amount,
                    n_deallocation_amount,
                    d_allocation_date
                  FROM allocation
                  WHERE n_allocation_id = allo.n_allocation_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Allocation in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     Msg:='Error:Allocation in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                     Rollback;
                END;
              End loop;*/
              -- Copy sub_task_cancellation
             FOR stc IN
                (Select n_cancellation_id From sub_task_cancellation where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to sub task cancellation in sub area');
                BEGIN
                SELECT seq_sub_task_cancellation.nextval into new_attach_id from dual;
                INSERT INTO sub_task_cancellation (n_cancellation_id, n_sub_task_order_id, n_user_profile_id, c_reason, d_cancellation_ts)
                  SELECT new_attach_id,
                    new_sub_to_id,
                    n_user_profile_id,
                    c_reason,
                    sysdate
                  FROM sub_task_cancellation
                  WHERE n_cancellation_id = stc.n_cancellation_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Sub Task Cancellation in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:Sub Task Cancellation in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                     RAISE;
                END;
              End loop;
               -- Copy sub_task_region
              FOR str IN
                (Select n_region_id From subtask_region where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to sub task region in sub area');
                BEGIN
                INSERT INTO subtask_region (n_sub_task_order_id, n_region_id)
                  SELECT new_sub_to_id,
                    n_region_id
                  FROM subtask_region
                  WHERE n_region_id = str.n_region_id
                    and n_sub_task_order_id = sub.n_sub_task_order_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='SubTask Region in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:SubTask Region in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                     RAISE;
                END;
              End loop;
              -- Copy payment instruction item - for now do not include financial data CB 3/16/09
              /*FOR pii IN
                (Select n_payment_instruction_item_id From payment_instruction_item where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to payment instruction item in sub area');
                SELECT seq_payment_instruction_item.nextval into new_attach_id from dual;
                BEGIN
                INSERT INTO payment_instruction_item (n_payment_instruction_id, n_payment_instruction_item_id,
                  n_sub_task_order_id, n_delphi_obligation_id, n_invoice_item_id, n_amount)
                  SELECT n_payment_instruction_id,
                      new_attach_id,
                      new_sub_to_id,
                      n_delphi_obligation_id,
                      n_invoice_item_id,
                      n_amount
                  FROM payment_instruction_item
                  WHERE n_payment_instruction_item_id = pii.n_payment_instruction_item_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='Payment instruction itme in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     Msg:='Error:Payment instruction item in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                     Rollback;
                END;
              End loop;*/
              -- Copy ODC Cost
              FOR odc IN
                (Select n_odc_cost_id From odc_cost where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to odc cost in sub area');
                SELECT seq_odc_cost.nextval into new_attach_id from dual;
                BEGIN
                INSERT INTO odc_cost (n_odc_cost_id, n_odc_type_id, n_sub_task_order_id, n_odc_cost)
                  SELECT new_attach_id,
                      n_odc_type_id,
                      new_sub_to_id,
                      n_odc_cost
                  FROM odc_cost
                  WHERE n_odc_cost_id = odc.n_odc_cost_id;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='ODC cost in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     status_out:='Error:ODC Cost in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(status_out);
                     RAISE;
                END;
              End loop;
              /*FOR tom IN
                (Select to_number, sub_task From task_order_mapping where n_sub_task_order_id = sub.n_sub_task_order_id)
              LOOP
                dbms_output.put_line('up to task order mapping in sub area');
                BEGIN
                INSERT INTO task_order_mapping (to_number, sub_task, n_task_order_id, n_sub_task_order_id, c_task_order_number)
                  SELECT to_number,
                      sub_task,
                      new_to_id,
                      new_sub_to_id,
                      c_task_order_number
                  FROM task_order_mapping
                  WHERE to_number = tom.to_number
                    and sub_task = tom.sub_task;

                 EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     Msg:='task order mapping in sub found no recs from subtask order:  '||sub.n_sub_task_order_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                  WHEN OTHERS THEN
                     Msg:='Error:Task order mapping in sub for :' ||  new_sub_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                     dbms_output.put_line(Msg);
                     Rollback;
                END;
              End loop;*/
        End loop;  -- End Sub task loop
        --dbms_output.put_line('new sub task is ' || new_sub_to_id);
        -- Copy the following tables using the new task order id: Attachment, Transaction, Rejection Reason, Note Comment
        -- Deliverable

          FOR Attach In
            (Select n_attachment_id From attachment where n_object_id = to_id)
          LOOP
            dbms_output.put_line('up to attachment');
            BEGIN
            SELECT seq_attachment.nextval into new_attach_id from dual;
            INSERT INTO attachment (N_ATTACHMENT_ID, N_OBJECT_ID, C_OBJECT_TYPE, C_ATTACHMENT_TITLE,
              C_ATTACHMENT_TYPE, C_FILE_NAME, C_FILE_EXT, C_FILE_TYPE, C_FILE_SUB_TYPE, N_FILE_SIZE,
              F_ATTACHED_FILE, D_REC_VERSION, N_USER_PROFILE_ID, C_USER_ROLE)
              SELECT new_attach_id,
                new_to_id,
                c_object_type,
                c_attachment_title,
                c_attachment_type,
                c_file_name,
                c_file_ext,
                c_file_type,
                c_file_sub_type,
                n_file_size,
                f_attached_file,
                sysdate,
                n_user_profile_id,
                c_user_role
              FROM attachment
              WHERE n_attachment_id = attach.n_attachment_id;

             EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='Attachment found no recs from task order:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 status_out:='Error:attachment for :' ||  new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(status_out);
                RAISE;
            END;
          End loop;
          --End IF;
          -- Copy Transaction where task order id
            FOR Trans In
              (Select n_transaction_id From transaction where n_task_order_id = to_id)
            LOOP
              dbms_output.put_line('up to transaction');
              BEGIN
              SELECT seq_transaction.nextval into new_trans_id from dual;
              INSERT INTO transaction (N_TRANSACTION_ID, N_TASK_ORDER_ID, N_USER_REQUEST_ID, N_USER_PROFILE_ID,
                N_ACTION_ID, N_CHANGE_ID, D_TRANSACTION_DATE, T_COMMENTS)
                SELECT new_trans_id,
                  new_to_id,
                  n_user_request_id,
                  n_user_profile_id,
                  n_action_id,
                  n_change_id,
                  d_transaction_date,
                  t_comments

                FROM transaction
                WHERE n_transaction_id = trans.n_transaction_id;
               EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='transaction found no recs from task order:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 status_out:='Error:transaction for :' ||  new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(status_out);
                  RAISE;
             END;
            End loop;

          --Copy Rejection Reason
          FOR Rej In
              (Select n_reason_id From rejection_reason where n_task_order_id = to_id)
            LOOP
              dbms_output.put_line('up to reason');
              BEGIN
              SELECT seq_rejection_reason.nextval into new_trans_id from dual;
              INSERT INTO rejection_reason (n_reason_id, n_user_profile_id, n_task_order_id, t_reason, d_reason_ts)
                SELECT new_trans_id,
                  n_user_profile_id,
                  new_to_id,
                  t_reason,
                  sysdate
                FROM rejection_reason
                WHERE n_reason_id = Rej.n_reason_id;
               EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='reason found no recs from task order:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 status_out:='Error:reason for :' ||  new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(status_out);
                  RAISE;
             END;
            End loop;

        /*
       -- Copy Note Comment
          FOR Note In
              (Select n_note_id From note_comment where n_task_order_id = to_id
                and n_sub_task_order_id is null)
            LOOP
              dbms_output.put_line('up to note comment');
              BEGIN
              SELECT seq_note_comment.nextval into new_trans_id from dual;
              INSERT INTO note_comment (N_NOTE_ID, N_TASK_ORDER_ID, N_SUB_TASK_ORDER_ID, N_USER_PROFILE_ID,
                    D_NOTE_TS, T_COMMENT)
                SELECT new_trans_id,
                  new_to_id,
                  n_sub_task_order_id,
                  n_user_profile_id,
                  sysdate,
                  t_comment
                FROM note_comment
                WHERE n_note_id = Note.n_note_id;
               EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='note cmt found no recs from task order:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 status_out:='Error:note comment for :' ||  new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(status_out);
                  RAISE;
             END;
            End loop;
            */

          -- Copy extended Element
          FOR element In
            (Select n_element_id From extended_element where n_object_id = to_id and c_object_type = 'Task Order')
            LOOP
              dbms_output.put_line('up to extended element');
              BEGIN
              SELECT seq_extended_element.nextval into new_trans_id from dual;
              INSERT INTO extended_element (n_element_id, c_element_type, c_object_type, n_object_id,  cb_element)
              SELECT new_trans_id,
                c_element_type,
                c_object_type,
                new_to_id,
                cb_element
              FROM extended_element
              WHERE n_element_id = element.n_element_id;
               EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='extended element found no recs from task order:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 status_out:='Error:extended element for :' ||  new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(status_out);
                   RAISE;
             END;
            End loop;
          -- Copy Deliverable
          FOR DELIVERABLE IN
              (Select n_deliverable_id From deliverable where n_task_order_base_id = to_id
                and n_sub_task_order_id is null)
            LOOP
              dbms_output.put_line('up to deliverable');
              BEGIN
              SELECT SEQ_DELIVERABLE.NEXTVAL INTO NEW_TRANS_ID FROM DUAL;
              INSERT INTO DELIVERABLE (N_DELIVERABLE_ID, N_TASK_ORDER_BASE_ID, N_SUB_TASK_ORDER_ID,
                  CB_DESCRIPTION,  C_TYPE)
                SELECT new_trans_id,
                  new_to_id,
                  N_SUB_TASK_ORDER_ID,
                  cb_description,
                  c_type
                FROM deliverable
                WHERE n_deliverable_id = deliverable.n_deliverable_id;
               EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='deliverable found no recs from task order:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 status_out:='Error:deliverable for :' ||  new_to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(status_out);
                 RAISE;
             END;
            End loop;


            commit;
            status_out := 'Successful';
            return_new_to := new_to_id;
            -- Once Revision created inactivate original task order and set inactivate date
            -- move this section to activate task order
            /*BEGIN
              Update Task_order
              Set n_state_number = (select n_state_number from state where c_state_label = 'Inactive'),
                d_inactive_date = sysdate
              Where n_task_order_id = to_id;

              EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 Msg:='Original Task Order not found:  '||to_id||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
              WHEN OTHERS THEN
                 Msg:='Error:updating original Task Order for :' ||  to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                 dbms_output.put_line(Msg);
                 Rollback;
            END;*/
      ELSE
          status_out := 'Unsuccessful - Active Revision Exists Task Order Cannot be Revised';
          dbms_output.put_line(status_out);
          rollback;
      End if;
    ELSE
      --status_out := 'Unsuccessful - Task Order Cannot be Revised - TO: ' || to_id || created_id;
      status_out := 'Unsuccessful - Task Order Cannot be Revised';
      dbms_output.put_line(status_out);
      return;

End if;


EXCEPTION
       WHEN OTHERS THEN
          status_out:='Error:insert of task order record: ' ||  to_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
          dbms_output.put_line(status_out);

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
          'CREATE REVISION',
          NULL,
          'ERROR',
          'Error processing Create Revision.',
           lv_msg,
          NULL,
          SYSDATE
           );

       COMMIT;


END;
/
