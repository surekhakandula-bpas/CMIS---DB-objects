DROP PROCEDURE SP_DELETE_LAST_INVOICE;

CREATE OR REPLACE PROCEDURE              "SP_DELETE_LAST_INVOICE" AS 
nInvoice_ID Number;
BEGIN
select NVL(max(N_Invoice_ID),0) into nInvoice_ID  from KITT_NISC3.invoice;
if nInvoice_id > 0
  then
    delete from KITT_NISC3.invoice_item_warning_msg where n_invoice_id = nInvoice_ID;
    delete from KITT_NISC3.invoice_item where N_Invoice_ID = nInvoice_ID;
    delete from KITT_NISC3.invoice where N_Invoice_ID = nInvoice_ID;
    delete from KITT_NISC3.k3_invoice_line_item b where b.invoice_id = (select Invoice_ID from k3_invoice_header a where a.invoice_number = nInvoice_ID);
    delete from KITT_NISC3.k3_invoice_header a where a.invoice_number = nInvoice_ID;
    
  end if;
END SP_DELETE_LAST_INVOICE;
/
