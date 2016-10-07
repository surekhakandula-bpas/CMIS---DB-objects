DROP PROCEDURE INVOICE_SEND_VOUCHER_EMAIL;

CREATE OR REPLACE PROCEDURE            INVOICE_SEND_VOUCHER_EMAIL (
                                         MyKITTContractNum varchar2,
                                         MyInvoiceID     number)

AS

/******************************************************************************
   NAME:       INVOICE_SEND_VOUCHER_EMAIL
   PURPOSE:   Send an email notification after CTR BUSINESS OPS
              signs the invoice voucher


   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/28/2010  Chao Yu        1. Created this procedure.
   1.2      10/08/2010  Chao Yu        2. Call from package PK_INVOICE_LOADING
******************************************************************************/


BEGIN

  PK_INVOICE_LOADING.INVOICE_SEND_VOUCHER_EMAIL ( MyKITTContractNum,MyInvoiceID );


EXCEPTION
   WHEN OTHERS then
    null;
END;
/
