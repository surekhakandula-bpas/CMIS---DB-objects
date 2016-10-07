DROP PROCEDURE INVOICE_GET_SUBTO_FUND;

CREATE OR REPLACE PROCEDURE              "INVOICE_GET_SUBTO_FUND" (
                                           MyTaskOrderBaseID number,
                                           MySubTaskOrderName varchar2,
                                           MyInvoiceID  number,
                                           MyAvailableFund out number) AS 
PenddingInvoiceAmount number;
MyETOAvailableFund number;
BEGIN
  select SUB_TASK_AVAILABLE_AMOUNT into  MyAvailableFund
       from KITT_NISC3.V_KITTV_SUBTO_AVAILABLE_AMOUNT
      where N_TASK_ORDER_BASE_ID = MyTaskOrderBaseID
        and C_SUB_TASK_ORDER_NAME = MySubTaskOrderName;
EXCEPTION
     WHEN NO_DATA_FOUND THEN
       MyAvailableFund:= 0;
     WHEN OTHERS THEN
       MyAvailableFund:= 0;
       Raise;
END INVOICE_GET_SUBTO_FUND;
/
