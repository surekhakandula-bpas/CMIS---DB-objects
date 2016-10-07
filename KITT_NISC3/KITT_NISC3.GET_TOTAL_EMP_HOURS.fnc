DROP FUNCTION GET_TOTAL_EMP_HOURS;

CREATE OR REPLACE FUNCTION            get_total_emp_hours (
   employee_id           IN NUMBER,
   invoice_id            IN NUMBER,
   task_order_base_id    IN NUMBER,
   sub_task_order_name   IN VARCHAR2,
   cost_type_id          IN NUMBER)
   RETURN NUMBER
IS
   total_hours   NUMBER;
BEGIN
   SELECT SUM (II.N_QUANTITY)
     INTO total_hours
     FROM INVOICE_ITEM II
    WHERE     II.N_INVOICE_ID = invoice_id
          AND II.N_EMPLOYEE_ID = employee_id
          AND II.N_TASK_ORDER_BASE_ID = task_order_base_id
          AND II.C_SUB_TASK_ORDER_NAME = sub_task_order_name
          AND II.N_COST_TYPE_ID = cost_type_id;

   RETURN (total_hours);
END;
/
