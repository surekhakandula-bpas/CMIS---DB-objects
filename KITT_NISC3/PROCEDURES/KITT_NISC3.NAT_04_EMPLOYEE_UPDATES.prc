DROP PROCEDURE NAT_04_EMPLOYEE_UPDATES;

CREATE OR REPLACE PROCEDURE            "NAT_04_EMPLOYEE_UPDATES" (
   InvoiceID    NUMBER)
AS
   NewInvoiceID   NUMBER;
BEGIN
   NewInvoiceID := InvoiceID;

   UPDATE EMPLOYEE E
      SET (E.C_FIRST_NAME, E.C_LAST_NAME) =
             (SELECT i.employee_firstname, i.employee_lastname
                FROM nat_invoice_line_item i
               WHERE     e.n_nisc_id = i.employee_id
                     AND i.invoice_number = NewInvoiceID
                     AND ROWNUM = 1)
    WHERE EXISTS
             (SELECT 1
                FROM nat_invoice_line_item i
               WHERE     e.n_nisc_id = i.employee_id
                     AND i.invoice_number = NewInvoiceID);

   COMMIT;
END NAT_04_EMPLOYEE_UPDATES;
/
