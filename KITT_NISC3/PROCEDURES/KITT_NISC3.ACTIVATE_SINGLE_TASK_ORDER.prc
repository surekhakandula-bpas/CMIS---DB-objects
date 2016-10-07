DROP PROCEDURE ACTIVATE_SINGLE_TASK_ORDER;

CREATE OR REPLACE PROCEDURE            ACTIVATE_SINGLE_TASK_ORDER(p_n_task_order_id in NUMBER, status_out OUT VARCHAR2) AS

/******************************************************************************
   NAME:       ACTIVATE_SINGLE_TASK_ORDER
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        6/07/2010   Jon Goff        1. Created to allow single task order activation
   2.0        6/08/2010   Chao Yu       2. Hanlded the new pending status 313
   3.0        6/10/2010   Chao Yu       3  Handle sub task order convert from closed to revised
   4.0        9/29/2010   Jon Goff        1. Removed allocation requirements
   4.1        04/13/2011  Jon Goff      1.  Added final exception

   Procedure scheduled to run daily setting state to active for any task order meeting
   conditions.

******************************************************************************/



is_valid_to                number(9);
ctr2                    NUMBER(9);
revisions             number(9);
revised_by           number(9);
eto_id                  number(9);
previous_to          number(9) :=0;
current_to              number(9);
newsub_for_invoice  number(9);
new_subid           number(9);
new_alloc_id        number(9);
new_status          varchar2(30);
lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

BEGIN


      dbms_output.put_line('up to funded tos: ' ||p_n_task_order_id);
      ctr2:=0;
      -- Update state to active
      BEGIN
        UPDATE task_order
           SET N_STATE_NUMBER =  (Select N_state_number from state where C_state_label = 'Active'), -- want 103
               d_active_date = sysdate
         WHERE n_task_order_id = p_n_task_order_id;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          status_out:='No task order found to update'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
          dbms_output.put_line(status_out);
        WHEN OTHERS THEN
          status_out:='Error: Update to active of executed task order failed: ' || p_n_task_order_id || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
          dbms_output.put_line(status_out);
          RAISE;
      END;
      -- BEGIN
      -- check for revision and then for allocations
      SELECT n_task_order_revision, n_previous_task_order_id, n_task_order_id, n_created_by_id, n_eto_id
        INTO revisions, previous_to, current_to, revised_by, eto_id
        FROM task_order
       WHERE n_task_order_id = p_n_task_order_id;

      IF revisions > 0 THEN
                -- Update invoice item records from old subtask to new subtask for when invoice status < 306
                -- or before payment instructions created.
        FOR oldsubs IN
          ( SELECT s.n_sub_task_order_id, s.c_sub_task_order_name
              FROM sub_task_order s
             WHERE s.n_task_order_id = previous_to )
        LOOP
          SELECT n_sub_task_order_id
            INTO newsub_for_invoice
            FROM sub_task_order
           WHERE n_task_order_id = current_to
             AND c_sub_task_order_name = oldsubs.c_sub_task_order_name;

          dbms_output.put_line('next do loop to update invoice item from old sub: '|| oldsubs.n_sub_task_order_id || 'to new sub: ' || newsub_for_invoice);

          FOR Invoices IN
            ( SELECT ii.n_invoice_item_id, ii.n_sub_task_order_id
                FROM invoice i, invoice_item ii
               WHERE i.n_invoice_id = ii.n_invoice_id
                 AND i.n_status_number NOT IN (306, 307, 308, 309, 310, 311) -- Changed by chao from i.n_status_number <306  and handled the new status 313
                 AND ii.n_sub_task_order_id = oldsubs.n_sub_task_order_id)
          LOOP
            BEGIN
              UPDATE invoice_item
                 SET n_sub_task_order_id = newsub_for_invoice
               WHERE n_invoice_item_id = invoices.n_invoice_item_id;
            EXCEPTION
              WHEN OTHERS THEN
                status_out:='Error:updating invoice item for subid:' ||  new_subid || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                dbms_output.put_line(status_out);
                RAISE;
            END;
          END LOOP;  -- end invoice loop
        END LOOP;  -- end oldsubs loop




       /*
       --Commented out changes for allocation

        BEGIN
            -- Funds allocated on original task order moved to revision and original closed and moved to state Revised.
          SELECT count(*) into ctr2
            FROM task_order t, sub_task_order s, v_revision_subto_remaining v --allocation a
           WHERE t.n_task_order_id = s.n_task_order_id
             AND s.n_sub_task_order_id = v.n_sub_task_order_id
             AND t.n_task_order_id = previous_to;                 --previous task order
                --Group By t.n_task_order_id
                --Having (sum(a.n_allocation_amount) - sum(nvl(a.n_deallocation_amount,0))) > 0;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            ctr2:=0;
            status_out:='No funded original task order found'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
            dbms_output.put_line(status_out);
          WHEN OTHERS THEN
            status_out:='Error: on selecting allocation on original: ' || previous_to || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
            dbms_output.put_line(status_out);
            ROLLBACK;
        END;

        dbms_output.put_line('ctr2 for funded is: '||ctr2);
            -- New section based on Jira tkt #kt-842, deallocate remaining money from old task order and allocate to new
        IF NVL(ctr2,0) > 0 THEN
                -- Funds allocated on previous task order, get subtasks of previous to then get records from view that match
                --FOR subs IN
                  --(Select s.n_sub_task_order_id, s.c_sub_task_order_name
                   --From sub_task_order s
                   --Where s.n_task_order_id = previous_to)
          FOR subs IN
            ( SELECT s.n_sub_task_order_id, s.c_sub_task_order_name
                FROM sub_task_order s, v_revision_subto_remaining v
               WHERE s.n_sub_task_order_id = v.n_sub_task_order_id
                 AND s.n_task_order_id = previous_to)
          LOOP
                  -- Get new subtask id and check that it is not cancelled, if cancelled bypass deallocation and allocation
                  -- Cancelled check removed based on 8/19 Sjawn email
            SELECT s.n_sub_task_order_id, st.c_status_label
              INTO new_subid, new_status
              FROM sub_task_order s, status st
             WHERE s.n_task_order_id = current_to
               AND s.n_status_number = st.n_status_number
               AND s.c_sub_task_order_name = subs.c_sub_task_order_name;

            dbms_output.put_line('up to insert for deallocation for subid: ' ||subs.n_sub_task_order_id);
                   -- loop through view for all records of the current sub task
            FOR viewrecs IN
              ( SELECT v.n_delphi_obligation_id as delphi_id, f_fee as fee, remaining_fund as remaining
                       --Into delphi_id, fee, remaining
                  FROM v_revision_subto_remaining v
                 WHERE v.n_sub_task_order_id = subs.n_sub_task_order_id)
                  --IF new_status != 'Cancelled'
                  --THEN
            LOOP
              BEGIN
                        -- deallocate part
                SELECT seq_allocation.nextval into new_alloc_id from dual;

                INSERT INTO allocation(n_allocation_id, n_sub_task_order_id, n_user_profile_id,
                          n_delphi_obligation_id, n_eto_id, n_allocation_amount, n_deallocation_amount, d_allocation_date, f_fee)
                  VALUES(new_alloc_id,
                          subs.n_sub_task_order_id,
                          revised_by,
                          viewrecs.delphi_id,
                          eto_id,
                          0,
                          viewrecs.remaining,
                          sysdate,
                          viewrecs.fee);
              EXCEPTION
                WHEN OTHERS THEN
                  status_out:='Error:inserting deallocation for subid: ' ||  subs.n_sub_task_order_id || ' ,fee:' || viewrecs.fee ||to_char(SQLCODE) ||'-'||SQLERRM;
                  dbms_output.put_line(status_out);
                  ROLLBACK;
              END;

                    -- allocate part
              dbms_output.put_line('up to allocation' || 'for subid: ' || new_subid);
              BEGIN
                SELECT seq_allocation.nextval into new_alloc_id from dual;

                INSERT INTO allocation(n_allocation_id, n_sub_task_order_id, n_user_profile_id,
                            n_delphi_obligation_id, n_eto_id, n_allocation_amount, n_deallocation_amount, d_allocation_date, f_fee)
                  VALUES (new_alloc_id,
                            new_subid,
                            revised_by,
                            viewrecs.delphi_id,
                            eto_id,
                            viewrecs.remaining,
                            0,
                            sysdate,
                            viewrecs.fee);

              EXCEPTION
                WHEN OTHERS THEN
                  status_out:='Error:inserting allocation for subid:' ||  new_subid || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                  dbms_output.put_line(status_out);
                  ROLLBACK;
              END;
            END LOOP;  -- end loop of view records

                    -- End if;  end if for cancelled
          END LOOP;
        END IF;

        */




              -- Based on 4/23/09 meeting with Sjawn allocations are not to be moved to revision
              -- commented out what is currently lines 115-205
             /*IF NVL(ctr2,0) > 0 then
                -- Funds allocated on previous task order
                dbms_output.put_line('About to update current '|| p_n_task_order_id ||' and previous to ' ||previous_to);
               -- BEGIN
                    -- Loop through allocation records of original task order
                    FOR alloc IN
                      (Select a.n_allocation_id
                      From allocation a, task_order t, sub_task_order s
                      where t.n_task_order_id = previous_to
                      and t.n_task_order_id = s.n_task_order_id
                      and a.n_sub_task_order_id = s.n_sub_task_order_id)
                    LOOP
                    dbms_output.put_line('up to deallocation of record: ' || alloc.n_allocation_id);
                    dbms_output.put_line('About to update'|| p_n_task_order_id);
                    -- Store allocation amt from previous to
                    SELECT n_allocation_amount into alloc_amt
                    FROM allocation
                    WHERE n_allocation_id = alloc.n_allocation_id;
                    BEGIN
                      -- deallocate part
                      SELECT seq_allocation.nextval into new_alloc_id from dual;
                      INSERT INTO allocation(n_allocation_id, n_sub_task_order_id, n_user_profile_id,
                        n_delphi_obligation_id, n_eto_id, n_allocation_amount, n_deallocation_amount, d_allocation_date, f_fee)
                      SELECT new_alloc_id,
                        n_sub_task_order_id,
                        n_user_profile_id,
                        n_delphi_obligation_id,
                        n_eto_id,
                        0,
                        alloc_amt,
                        sysdate,
                        f_fee
                      FROM allocation
                      WHERE n_allocation_id = alloc.n_allocation_id;
                      -- Deallocated original task order, next allocate to revision

                       EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       status_out:='Original Task Order allocatin not found:  '||previous_to||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                       dbms_output.put_line(status_out);
                    WHEN OTHERS THEN
                       status_out:='Error:inserting deallocation for :' ||  previous_to || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                       dbms_output.put_line(status_out);
                       Rollback;
                    END;
                    --BEGIN
                      -- Get subtask id of revised records
                      SELECT s.c_sub_task_order_name into subname
                      from allocation a, task_order t, sub_task_order s
                      where t.n_task_order_id = previous_to
                        and a.n_allocation_id = alloc.n_allocation_id
                        and t.n_task_order_id = s.n_task_order_id
                        and a.n_sub_task_order_id = s.n_sub_task_order_id;
                      dbms_output.put_line('subname is ' || subname || ' alloc.n_allocation_id is ' || alloc.n_allocation_id);
                      dbms_output.put_line('taskorder id is ' || p_n_task_order_id);

                      SELECT s.n_sub_task_order_id into new_subid
                      FROM Sub_task_order s, task_order t
                      WHERE s.c_sub_task_order_name = subname
                        and t.n_task_order_id = s.n_task_order_id
                        and t.n_task_order_id = p_n_task_order_id;
                      dbms_output.put_line('subtaskorder id is ' || new_subid);
                      -- allocate part
                      dbms_output.put_line('up to allocation of record: ' || alloc.n_allocation_id || 'for subid: ' || new_subid);
                      BEGIN
                        SELECT seq_allocation.nextval into new_alloc_id from dual;
                        INSERT INTO allocation(n_allocation_id, n_sub_task_order_id, n_user_profile_id,
                          n_delphi_obligation_id, n_eto_id, n_allocation_amount, n_deallocation_amount, d_allocation_date, f_fee)
                        SELECT new_alloc_id,
                          new_subid,
                          n_user_profile_id,
                          n_delphi_obligation_id,
                          n_eto_id,
                          alloc_amt,
                          0,
                          sysdate,
                          f_fee
                        FROM allocation
                        WHERE n_allocation_id = alloc.n_allocation_id;

                         EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                         status_out:='Original Task Order allocation not found:  '||previous_to||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                         dbms_output.put_line(status_out);
                      WHEN OTHERS THEN
                         status_out:='Error:inserting original Task Order for :' ||  previous_to || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
                         dbms_output.put_line(status_out);
                         Rollback;
                    END;
                    END Loop;
                  END IF;*/

              -- Update previous task order to closed - revised
        BEGIN
                      -- Inactivate original task order
          UPDATE Task_order
             SET n_state_number = (select n_state_number from state where upper(c_state_label) = 'REVISED'),
                          N_STATUS_NUMBER = 102,     -- Added by chao
                          N_OWNERSHIP_NUMBER = 110,  -- Added by chao
                          d_inactive_date = sysdate
           WHERE n_task_order_id = previous_to;

          update SUB_TASK_ORDER         -- Added by chao to handle sub task order convert from closed to revised
             set N_STATE_NUMBER = null,
                 N_STATUS_NUMBER = 100
           where N_STATE_NUMBER = 104
             and N_STATUS_NUMBER = 500
             and n_task_order_id = previous_to;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            status_out:='Original Task Order not found:  '||previous_to||' '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
            dbms_output.put_line(status_out);
          WHEN OTHERS THEN
            status_out:='Error:updating original Task Order for :' ||  previous_to || ' ' || to_char(SQLCODE) ||'-'||SQLERRM;
            dbms_output.put_line(status_out);
            RAISE;
        END;
      END IF; -- end if revision


 status_out := 'Successful';

EXCEPTION
    WHEN OTHERS THEN

    IF STATUS_OUT IS NULL THEN
        STATUS_OUT :=' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
    ELSE
       STATUS_OUT := 'Error:  '||STATUS_OUT;
    END IF;    --This will allow the value of STATUS_OUT to the UI if raised above

 End ACTIVATE_SINGLE_TASK_ORDER;
/
