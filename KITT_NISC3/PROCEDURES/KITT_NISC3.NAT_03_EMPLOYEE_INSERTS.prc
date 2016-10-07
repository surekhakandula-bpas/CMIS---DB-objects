DROP PROCEDURE NAT_03_EMPLOYEE_INSERTS;

CREATE OR REPLACE PROCEDURE            "NAT_03_EMPLOYEE_INSERTS" (
   InvoiceID    NUMBER)
AS
   NewInvoiceID   NUMBER;
BEGIN
   NewInvoiceID := InvoiceID;

   INSERT INTO KITT_NISC3.EMPLOYEE (N_EMPLOYEE_ID,
                                    N_CONTRACTOR_ID,
                                    C_FIRST_NAME,
                                    C_LAST_NAME,
                                    N_NISC_ID)
      SELECT SEQ_EMPLOYEE.NEXTVAL AS N_EMPLOYEE_ID,
             N_CONTRACTOR_ID,
             C_FIRST_NAME,
             C_LAST_NAME,
             N_NISC_ID
        FROM (SELECT distinct (SELECT max(N_CM_KITT2_ID)
                                 FROM KITT_NISC3.CONTRACTOR_MAP
                                WHERE N_CM_NAT_ID = company_id)
                                 AS N_CONTRACTOR_ID,
                              employee_firstname AS C_FIRST_NAME,
                              employee_lastname AS C_LAST_NAME,
                              employee_id AS N_NISC_ID
                FROM nat_invoice_line_item
               WHERE     employee_id NOT IN (SELECT n_nisc_id FROM employee)
                     AND invoice_number = NewInvoiceID);

   COMMIT;
END NAT_03_EMPLOYEE_INSERTS;
/
