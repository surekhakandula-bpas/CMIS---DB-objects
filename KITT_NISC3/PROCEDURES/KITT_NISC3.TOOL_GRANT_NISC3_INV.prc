DROP PROCEDURE TOOL_GRANT_NISC3_INV;

CREATE OR REPLACE PROCEDURE            TOOL_GRANT_NISC3_INV IS

/******************************************************************************
   NAME:       TOOL_GRANT_NISC3_INV 
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        6/23/2010    Chao Yu       1. Created this procedure.

 
******************************************************************************/
BEGIN
  
  
   
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_COST_TYPE to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_INVOICE_ITEM_REJECTED to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_LABOR_CATEGORY to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_ODC_COST to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_ODC_TYPE to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_SUBTO_INVOICE_BASE to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_SUBTO_LABOR_CATEGORY to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_SUB_TASK_ORDER to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_TASK_ORDER to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_PAID_PENDING_HOURS to KITT_NISC3_INV';
   EXECUTE IMMEDIATE 'Grant select on V_KITTV_INVOICE_REJECTED to KITT_NISC3_INV';
   
   
   



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_GRANT_NISC3_INV; 
/
