DROP FUNCTION GET_TOTAL_HOURS_BY_TOSUBTASK;

CREATE OR REPLACE FUNCTION            get_total_hours_by_TOSubtask (
   invoice_id            IN NUMBER,
   task_order_base_id    IN NUMBER,
   sub_task_order_name   IN VARCHAR2)
   RETURN NUMBER
IS
   total_hours   NUMBER;
BEGIN
   SELECT SUM (II.N_QUANTITY)
     INTO total_hours
     FROM INVOICE_ITEM II
    WHERE     II.N_INVOICE_ID = invoice_id
          AND II.N_TASK_ORDER_BASE_ID = task_order_base_id
          AND II.C_SUB_TASK_ORDER_NAME = sub_task_order_name;

   RETURN (total_hours);
END;
/
