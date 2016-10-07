DROP PACKAGE PK_K3K2_INVOICE_LOADING;

CREATE OR REPLACE PACKAGE              "PK_K3K2_INVOICE_LOADING" AS 

  /* TODO enter package declarations (types, exceptions, methods etc) here */ 
  
  PROCEDURE SP_LOADK3_RI_DATA;
  procedure SP_LoadStaging_K3;
  Procedure SP_Migration(Delete_Last_Processed_Invoice char);
  

END PK_K3K2_INVOICE_LOADING;
/
