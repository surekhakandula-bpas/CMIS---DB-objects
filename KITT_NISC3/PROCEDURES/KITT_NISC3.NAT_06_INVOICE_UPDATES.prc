DROP PROCEDURE NAT_06_INVOICE_UPDATES;

CREATE OR REPLACE PROCEDURE            "NAT_06_INVOICE_UPDATES" (
   InvoiceID    NUMBER)
AS
   NewInvoiceID   NUMBER;
BEGIN
   NewInvoiceID := InvoiceID;

   UPDATE INVOICE_ITEM
      SET n_invoice_period_year_month =
                CAST (TO_CHAR (d_mis_charge_date, 'yyyy') AS VARCHAR2 (4))
             || CAST (TO_CHAR (d_mis_charge_date, 'MM') AS VARCHAR2 (2))
    WHERE n_invoice_id = NewInvoiceID;

   COMMIT;

   UPDATE INVOICE_ITEM
      SET n_invoice_adj_id = 42
    WHERE     n_invoice_id = NewInvoiceID
          AND n_invoice_period_year_month = 201312;

   COMMIT;

   UPDATE INVOICE_ITEM Z
      SET n_sub_task_order_id =
             (SELECT DISTINCT B.N_SUB_TASK_ORDER_ID
                FROM task_order A, Sub_task_order B
               WHERE     A.N_STATE_NUMBER IN (103, 104, 108)
                     AND A.N_TASK_ORDER_ID = B.N_TASK_ORDER_ID
                     AND z.N_INVOICE_ID = NewInvoiceID
                     AND z.n_task_order_base_id = A.n_task_order_base_id
                     AND z.C_SUB_TASK_ORDER_NAME = B.C_SUB_TASK_ORDER_NAME
                     AND B.N_sub_task_order_id > z.n_sub_task_order_id)
    WHERE EXISTS
             (SELECT DISTINCT z.N_SUB_TASK_ORDER_ID
                FROM task_order A, Sub_task_order B
               WHERE     A.N_STATE_NUMBER IN (103, 104, 108)
                     AND A.N_TASK_ORDER_ID = B.N_TASK_ORDER_ID
                     AND z.N_INVOICE_ID = NewInvoiceID
                     AND z.n_task_order_base_id = A.n_task_order_base_id
                     AND z.C_SUB_TASK_ORDER_NAME = B.C_SUB_TASK_ORDER_NAME
                     AND B.N_sub_task_order_id > z.n_sub_task_order_id);

   COMMIT;
END NAT_06_INVOICE_UPDATES;
/
