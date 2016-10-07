DROP FUNCTION GET_TOTAL_COST_BY_TYPE;

CREATE OR REPLACE FUNCTION            get_total_cost_by_type (
   invoice_id            IN NUMBER,
   task_order_base_id    IN NUMBER,
   sub_task_order_name   IN VARCHAR2,
   cost_type_id          IN NUMBER)
   RETURN NUMBER
IS
   total_cost   NUMBER;
BEGIN
   SELECT SUM (II.N_FAA_COST)
     INTO total_cost
     FROM INVOICE_ITEM II
    WHERE     II.N_INVOICE_ID = invoice_id
          AND II.N_TASK_ORDER_BASE_ID = task_order_base_id
          AND II.C_SUB_TASK_ORDER_NAME = sub_task_order_name
          AND II.N_COST_TYPE_ID = cost_type_id;

   RETURN (total_cost);
END;
/
