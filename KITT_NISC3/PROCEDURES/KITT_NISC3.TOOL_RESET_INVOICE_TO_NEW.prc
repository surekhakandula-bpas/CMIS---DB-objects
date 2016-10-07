DROP PROCEDURE TOOL_RESET_INVOICE_TO_NEW;

CREATE OR REPLACE PROCEDURE           TOOL_RESET_INVOICE_TO_NEW (MyInvoiceID number := 0)
IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       TOOL_RESET_INVOICE_TO_NEW 
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/25/2009          1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     RESET_INVOICE_TO_NEW
      Sysdate:         2/25/2009
      Date and Time:   2/25/2009, 11:52:28 AM, and 2/25/2009 11:52:28 AM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
BEGIN
   

   update invoice
   set D_AP_RECEIVED_DATE = null,
       D_PAYMENT_DUE_DATE = null,
       D_CERTIFICATION_DUE_DATE = null,
       F_ETO_SAVED_OR_CERTIFIED = null,
       F_PMO_SAVED_OR_CERTIFIED = null,
       C_INVOICE_STATUS ='NEW',
       N_STATUS_NUMBER =300,
       N_PMO_ID=null,
       N_AP_ID = null
  where N_INVOICE_ID =MyInvoiceID;
  commit;
  
   update INVOICE_ITEM 
      set T_ETO_COMMENTS = null,
          T_PMO_COMMENTS = null,
          F_ETO_DISPUTE_FLAG = null,
          F_PMO_DISPUTE_FLAG = null,
          N_ETO_REJECT_REASON_ID = null,
          N_PMO_REJECT_REASON_ID = null,
          T_ETO_REJECT_REASON = null,
          T_PMO_REJECT_REASON = null,
          T_ETO_OTHER_REJECT_REASON = null,
          T_PMO_OTHER_REJECT_REASON = null,
          F_ETO_CERT_FLAG ='N',
          F_ETO_REVIEW_FLAG = 'N',
          F_PMO_REVIEW_FLAG = 'N',
          D_ETO_CERT_TS =null,
          D_ETO_REVIEW_TS = null,
          D_PMO_REVIEW_TS = null,
          N_CERT_ETO_ID = null,
          N_REVIEW_ETO_ID = null,
          N_REVIEW_PMO_ID = null
   where N_INVOICE_ID =MyInvoiceID;
   commit;
  
  delete from INVOICE_CERTIFICATION_LETTER
    where N_INVOICE_ID =MyInvoiceID;
   commit;
   
   delete from Invoice_Service
    where n_voucher_id = (select invoice_service.n_voucher_id
        from invoice_service, invoice_voucher
        where invoice_service.n_voucher_id = invoice_voucher.n_voucher_id
        and invoice_voucher.n_invoice_ID =MyInvoiceID);
   commit;
   
   delete from Invoice_Voucher
   where n_invoice_id =MyInvoiceID;
   commit;
        
   delete from CONTRACT_DSA
    where N_OBJECT_ID =MyInvoiceID
      and c_object_type in ('ICF', 'NPL', 'Invoice Voucher');
   commit;
    
    delete from PAYMENT_INSTRUCTION_ITEM
     where N_PAYMENT_INSTRUCTION_ID in 
        ( select N_PAYMENT_INSTRUCTION_ID
           from PAYMENT_INSTRUCTION
           where N_INVOICE_ID =MyInvoiceID);
   commit;
   
   delete from PAYMENT_INSTRUCTION
   where N_INVOICE_ID =MyInvoiceID;
   commit;
           
           
   delete from credit
    where N_INVOICE_ITEM_ID in ( select N_INVOICE_ITEM_ID 
                                   from invoice_item 
                                  where N_INVOICE_ID =MyInvoiceID );
                                  
   commit;
   
   delete from INVOICE_ADJUSTMENT
    where N_INVOICE_ITEM_ID in ( select N_INVOICE_ITEM_ID 
                                   from invoice_item 
                                  where N_INVOICE_ID =MyInvoiceID );
   commit;
  
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_RESET_INVOICE_TO_NEW; 
/
