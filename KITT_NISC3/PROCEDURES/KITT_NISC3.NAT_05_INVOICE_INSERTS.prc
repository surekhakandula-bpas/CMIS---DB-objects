DROP PROCEDURE NAT_05_INVOICE_INSERTS;

CREATE OR REPLACE PROCEDURE            "NAT_05_INVOICE_INSERTS" (
   InvoiceID    NUMBER)
AS
   NewInvoiceID   NUMBER;
BEGIN
   NewInvoiceID := InvoiceID;

delete KITT_NISC3.Invoice WHERE N_INVOICE_ID = NewInvoiceID;
COMMIT;

   -- Insert Header for Invoice KITT2
   INSERT INTO KITT_NISC3.Invoice (n_invoice_id,
                                   n_Contract_ID,
                                   n_Invoice_Year_month,
                                   C_MIS_INVOICE_NUMBER,
                                   D_INVOICE_RECEIVED_DATE,
                                   C_INVOICE_STATUS,
                                   N_STATUS_NUMBER,
                                   C_INVOICE_DESC)
        VALUES (NewInvoiceID,
                101,
                (SELECT INVOICE_PERIOD
                   FROM NAT_INVOICE_HEADER
                  WHERE INVOICE_NUMBER = NewInvoiceID),
                NewInvoiceID,
                CURRENT_DATE,
                'New',
                300,
                (SELECT DESCRIPTION
                   FROM NAT_INVOICE_HEADER
                  WHERE INVOICE_NUMBER = NewInvoiceID));

   -- Get Max ID for Invoice
   --select Max(N_Invoice_ID) into NewInvoiceID from KITT_NISC3.Invoice;

delete KITT_NISC3.Invoice_Item WHERE N_INVOICE_ID = NewInvoiceID;
COMMIT;

   --Populate INvoice Item in KITT2
   INSERT INTO KITT_NISC3.Invoice_Item (N_INVOICE_ID,
                                        n_invoice_item_id,
                                        n_Task_Order_Base_ID,
                                        C_SUb_Task_order_Name,
                                        n_Sub_Task_Order_ID,
                                        n_contractor_ID,
                                        n_Employee_ID,
                                        n_Cost_Type_ID,
                                        n_Quantity,
                                        n_Cost,
                                        n_FAA_Cost,
                                        c_Description,
                                        n_ODC_Type_ID,
                                        n_Labor_Category_ID,
                                        n_Invoice_Adj_ID,
                                        D_MIS_Charge_Date,
                                        N_MIS_INVOICE_ITEM_ID,
                                        N_G_and_A,
                                        f_core,
                                        N_INVOICE_PERIOD_YEAR_MONTH)
      SELECT NewInvoiceID,
             (KITT_NISC3.seq_invoice_item.NEXTVAL),
             NVL (J.KH_N_Task_Order_Base_ID, A.taskorder) --Modified 04/07/2014 --A.BASE_TASK_ORDER_NUMBER
                                                         ,
             'Subtask ' || A.SUBTASK,
             NVL (
                (SELECT MAX (z.KH_N_SUBTASK_ORDER_ID)
                   FROM KITT_NISC3.SUB_TASK_ORDER_MAP z
                  WHERE     z.KH_N_Task_Order_Base_ID =
                               J.KH_N_Task_Order_Base_ID
                        AND UPPER (TRIM (A.SUBTASK)) =
                               UPPER (TRIM (z.k3_SUB_TASK_ORDER_NUMBER))),
                1) --,nvl(G.KH_N_Sub_Task_Order_ID,-1) --04/07/2014 Modified Sub task order mapping --- nvl((SELECT N_SUB_TASK_ORDER_ID FROM KITT_NISC3.SUB_TASK_ORDER G where A.TASK_ORDER_ID = G.N_TASK_ORDER_ID and rownum = 1 and  ('Subtask ' || A.SUB_TASK_ORDER_NUMBER) = G.C_SUB_TASK_ORDER_NAME ),-1)
                  ,
             NVL (b.n_cm_kitt2_id, 0),
             c.n_employee_id,
             CASE A.COSTTYPE_ID
                WHEN 1
                THEN
                   (SELECT H.N_CTM_KITT2_ID
                      FROM Cost_TYPE_MAP H
                     WHERE H.N_CTM_NAT_Labor_Type = A.SUBCOSTTYPE_ID)
                ELSE
                   (SELECT H.N_CTM_KITT2_ID
                      FROM Cost_TYPE_MAP H
                     WHERE H.N_CTM_NAT_ID = A.CostType_ID)
             END,
             CASE A.Costtype_Id
                WHEN 1 THEN (A.QUANTITY)
                WHEN 5 THEN (A.QUANTITY)
                ELSE 0
             END,
             NVL (A.RAW_COST, 0),
             NVL (A.TOTAL_COST, 0),
             A.Cost_Description,
             NVL (E.N_OTM_KITT2_ID, NULL),
             F.N_LCM_KITT2_ID,
             NVL (
                (SELECT n_Invoice_Id
                   FROM KITT_NISC3.Invoice
                  WHERE     ROWNUM = 1
                        AND (   CAST (
                                   TO_CHAR (A.DATE_INCURRED, 'yyyy') AS VARCHAR2 (4))
                             || CAST (
                                   TO_CHAR (A.DATE_INCURRED, 'MM') AS VARCHAR2 (2))) =
                               KITT_NISC3.Invoice.n_invoice_year_month),
                NewInvoiceID),
             A.DATE_INCURRED,
             nvl(X.EXTERNAL_ID_UPDATED,A.EXTERNAL_ID),
             0,
             'n/a',
                CAST (TO_CHAR (A.DATE_INCURRED, 'yyyy') AS VARCHAR2 (4))
             || CAST (TO_CHAR (A.DATE_INCURRED, 'MM') AS VARCHAR2 (2))
        FROM NAT_INVOICE_LINE_ITEM A
             LEFT OUTER JOIN Contractor_Map B ON A.Company_ID = B.N_CM_NAT_ID
             LEFT OUTER JOIN Employee C ON A.Employee_ID = C.N_NISC_ID
             --left outer join Cost_Type_Map D on A.CostType_ID = D.N_CTM_NAT_ID
             LEFT OUTER JOIN ODC_TYpe_Map E
                ON A.SUBCOSTTYPE_ID = E.N_OTM_NAT_ID
             --left outer join ODC_TYpe_Map L on A.LABOR_ODC_COST_TYPE_ID = L.N_OTM_KITT3_ID
             LEFT OUTER JOIN LABOR_CATEGORY_MAP F
                ON A.LABORCATEGORY_ID = F.N_LCM_NAT_ID
             --left outer join SUB_TASK_Order_MAP G on A.Sub_Task_Order_ID = G.K3_N_SUB_TASK_Order_ID
             LEFT OUTER JOIN TASK_Order_Map J
                ON A.TaskOrder = J.K3_N_Task_Order_ID
                
left outer join (
SELECT NAT_INVOICE_LINE_ITEM.EXTERNAL_ID,
       NAT_INVOICE_LINE_ITEM.EXTERNAL_ID || '00' EXTERNAL_ID_UPDATED 
  FROM NAT_INVOICE_LINE_ITEM
       INNER JOIN INVOICE_ITEM
          ON NAT_INVOICE_LINE_ITEM.EXTERNAL_ID =
                INVOICE_ITEM.N_MIS_INVOICE_ITEM_ID
 WHERE ( NAT_INVOICE_LINE_ITEM.INVOICE_NUMBER = NewInvoiceID )
) X on A.EXTERNAL_ID = X.EXTERNAL_ID
                
       WHERE A.INVOICE_NUMBER = NewInvoiceID;

   COMMIT;

END NAT_05_INVOICE_INSERTS;
/
