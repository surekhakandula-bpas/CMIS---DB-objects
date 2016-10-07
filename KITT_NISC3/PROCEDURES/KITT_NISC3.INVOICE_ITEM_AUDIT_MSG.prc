DROP PROCEDURE INVOICE_ITEM_AUDIT_MSG;

CREATE OR REPLACE PROCEDURE              "INVOICE_ITEM_AUDIT_MSG" (
                             MY_INVOICE_ID  number,
                             MY_INVOICE_ITEM_ID number,
                             MY_PROBLEM_ITEM varchar2,
                             MY_REASON varchar2,
                             MY_TYPE varchar2 ) AS 
BEGIN
  insert into KITT_NISC3.INVOICE_ITEM_WARNING_MSG
                           (
                             N_INVOICE_ID,
                             N_INVOICE_ITEM_ID,
                             C_PROBLEM_ITEM,
                             C_REASON,
                             C_TYPE,
                             D_AUDIT_DATE
                           )
         values
                           (
                             MY_INVOICE_ID,
                             MY_INVOICE_ITEM_ID,
                             MY_PROBLEM_ITEM,
                             MY_REASON,
                             MY_TYPE,
                             sysdate
                           );
        commit;
END INVOICE_ITEM_AUDIT_MSG;
/
