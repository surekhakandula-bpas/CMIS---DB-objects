DROP PROCEDURE TASK_ORDER_TOTALS;

CREATE OR REPLACE PROCEDURE            TASK_ORDER_TOTALS (TaskID_IN in NUMBER, Task_Order_ODC out NUMBER, Task_Order_Travel out NUMBER,
  Task_Order_Hours out number, Task_Order_Labor out number, Task_Order_Totals out number, resultset out sys_refcursor)

  AS

/******************************************************************************
   NAME:      Task_Order_Totals
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/14/2009   Cliff Baumen      1. Created this procedure.
   Procedure that accepts a task order id and returns totals for individual subtasks
   for the following: ODC, Travel, Hours and Labor
   2.0        05/27/2011  Tawfiq Diab
   Adjustments made to exclude the disputed invoice items, and invoice items that have not
   been processed for payments yet to get the actual cost of each subtask order in the
   provided task order id.
   Note1: actual cost of subtask A is the sum of the cost of subtask A in all task orders
   revisions that have the same base id.
   Note2: actual cost is the amount paid or (payment instruction created and signed by the CO)
   for that subtask
   Note3: input TaskId not TaskBaseId.
Verified by Tawfiq 6-1-2011
3.0      6/6/2011 : Excluded n_odc_type_id from the required items of including
   ODC charges in the totals.
4.0 Order subtasks proerly based on their name , A, B, ... Z, AA, ...etc.
******************************************************************************/

ODC_Total number(14,3) := 0;
Labor_Total number(14,3) := 0;
Hours_Total number(14,3) := 0;
Travel_Total number(14,3) := 0;

BEGIN

  -- Use system ref cursor to return recordset.

  BEGIN
    OPEN RESULTSET FOR
        SELECT DISTINCT TABLEE.C_SUB_TASK_ORDER_NAME, TABLEE.N_SUB_TASK_ORDER_ID,TABLEA.ODC_TOTAL,  TABLEB.TRAVEL_TOTAL,
            TABLEC.HOURS_TOTAL, TABLED.LABOR_TOTAL, (NVL(TABLEA.ODC_TOTAL, 0) + NVL(TABLEB.TRAVEL_TOTAL, 0) +
            NVL(TABLED.LABOR_TOTAL, 0)) AS SUBTASK_TOTAL
        FROM (
            SELECT SUM(II.N_FAA_COST) AS ODC_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S
            WHERE
                N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
            AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
            AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
            AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
            AND II.N_COST_TYPE_ID = 103
            AND II.N_QUANTITY=0
            GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLEA,
            (SELECT SUM(II.N_FAA_COST) AS TRAVEL_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S,COST_TYPE C
            WHERE
                N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
            AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
            AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
            AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
            AND II.N_COST_TYPE_ID = C.N_COST_TYPE_ID
            AND UPPER(C.C_COST_TYPE_LABEL)='TRAVEL'
            GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLEB,
            (SELECT SUM(II.N_QUANTITY) AS HOURS_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S,COST_TYPE C
            WHERE
                N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
            AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
            AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
            AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
            AND II.N_COST_TYPE_ID = C.N_COST_TYPE_ID
            AND UPPER(C.C_COST_TYPE_LABEL) IN ('HOURS', 'COMP', 'OT-NONEXEMPT', 'RATE_ADJ')
            GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLEC,
            (SELECT SUM(II.N_FAA_COST) AS LABOR_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S,COST_TYPE C
        WHERE
            N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
        AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
        AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
        AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
        AND II.N_COST_TYPE_ID = C.N_COST_TYPE_ID
        AND UPPER(C.C_COST_TYPE_LABEL) IN ('HOURS', 'COMP', 'OT-NONEXEMPT', 'RATE_ADJ')
        GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLED,
        (SELECT C_SUB_TASK_ORDER_NAME,N_SUB_TASK_ORDER_ID
        FROM SUB_TASK_ORDER
        --WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =146)
        WHERE N_TASK_ORDER_ID = TASKID_IN
         ) TABLEE
        WHERE TABLEE.C_SUB_TASK_ORDER_NAME = TABLEB.C_SUB_TASK_ORDER_NAME(+)
        AND TABLEE.C_SUB_TASK_ORDER_NAME = TABLEC.C_SUB_TASK_ORDER_NAME(+)
        AND TABLEE.C_SUB_TASK_ORDER_NAME = TABLED.C_SUB_TASK_ORDER_NAME(+)
        AND TABLEE.C_SUB_TASK_ORDER_NAME = TABLEA.C_SUB_TASK_ORDER_NAME(+)
        ORDER BY LENGTH(TABLEE.C_SUB_TASK_ORDER_NAME),TABLEE.C_SUB_TASK_ORDER_NAME;
    END;

   -- GET TOTALS OF INDIVIDUAL TOTAL FOR ENTIRE TASK ORDER

   BEGIN
        SELECT
            sum(TABLEA.ODC_TOTAL), sum(TABLEB.TRAVEL_TOTAL),
            sum(TABLEC.HOURS_TOTAL), sum(TABLED.LABOR_TOTAL)
            INTO ODC_Total, TRAVEL_TOTAL,HOURS_TOTAL, LABOR_TOTAL
        FROM (
            SELECT SUM(II.N_FAA_COST) AS ODC_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S
            WHERE
                 N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
            AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
            AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
            AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
            AND II.N_COST_TYPE_ID = 103
            AND II.N_QUANTITY=0
            GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLEA,
            (SELECT SUM(II.N_FAA_COST) AS TRAVEL_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S,COST_TYPE C
            WHERE
                N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
            AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                        WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
            AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
            AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
            AND II.N_COST_TYPE_ID = C.N_COST_TYPE_ID
            AND UPPER(C.C_COST_TYPE_LABEL)='TRAVEL'
            GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLEB,
            (SELECT SUM(II.N_QUANTITY) AS HOURS_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S,COST_TYPE C
            WHERE
                N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
            AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                        WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
            AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
            AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
            AND II.N_COST_TYPE_ID = C.N_COST_TYPE_ID
            AND UPPER(C.C_COST_TYPE_LABEL) IN ('HOURS', 'COMP', 'OT-NONEXEMPT', 'RATE_ADJ')
            GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLEC,
            (SELECT SUM(II.N_FAA_COST) AS LABOR_TOTAL,S.C_SUB_TASK_ORDER_NAME
            FROM INVOICE_ITEM II, SUB_TASK_ORDER S,COST_TYPE C
            WHERE
                N_INVOICE_ID IN(SELECT N_INVOICE_ID FROM INVOICE WHERE N_STATUS_NUMBER = 310)
            AND II.N_SUB_TASK_ORDER_ID IN(SELECT N_SUB_TASK_ORDER_ID FROM SUB_TASK_ORDER
                        WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =TASKID_IN))
            AND ((II.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II.F_PMO_DISPUTE_FLAG)='N' ))
            AND II.N_SUB_TASK_ORDER_ID = S.N_SUB_TASK_ORDER_ID
            AND II.N_COST_TYPE_ID = C.N_COST_TYPE_ID
            AND UPPER(C.C_COST_TYPE_LABEL) IN ('HOURS', 'COMP', 'OT-NONEXEMPT', 'RATE_ADJ')
            GROUP BY S.C_SUB_TASK_ORDER_NAME) TABLED,
            (SELECT C_SUB_TASK_ORDER_NAME,N_SUB_TASK_ORDER_ID
            FROM SUB_TASK_ORDER
            --WHERE N_TASK_ORDER_BASE_ID = (SELECT N_TASK_ORDER_BASE_ID FROM TASK_ORDER WHERE N_TASK_ORDER_ID =146)
                WHERE N_TASK_ORDER_ID = TaskID_IN
            ) TABLEE
        WHERE TABLEE.C_SUB_TASK_ORDER_NAME = TABLEB.C_SUB_TASK_ORDER_NAME(+)
        AND TABLEE.C_SUB_TASK_ORDER_NAME = TABLEC.C_SUB_TASK_ORDER_NAME(+)
        AND TABLEE.C_SUB_TASK_ORDER_NAME = TABLED.C_SUB_TASK_ORDER_NAME(+)
        AND TABLEE.C_SUB_TASK_ORDER_NAME = TABLEA.C_SUB_TASK_ORDER_NAME(+);
   END;



    Task_Order_Labor := Labor_Total;
    Task_Order_Hours := Hours_Total;
    Task_Order_Travel := Travel_Total;
    Task_Order_ODC := ODC_Total;
    Task_Order_Totals := nvl(Labor_Total, 0) + nvl(ODC_Total, 0) + nvl(Travel_Total, 0);
    --Task_Order_Totals := Labor_Total + Travel_Total + Travel_Total;
    dbms_output.put_line('finished procedure - total labor is: ' || Task_Order_Labor || ' total hrs are: '
      || Task_Order_Hours || ' total travel is: ' || Task_Order_Travel || ' total ODC is: ' || Task_Order_ODC);
END;
/
