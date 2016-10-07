DROP PROCEDURE TOOL_GRANT_KITT_META;

CREATE OR REPLACE PROCEDURE            TOOL_GRANT_KITT_META IS

/******************************************************************************
   NAME:       TOOL_GRANT_KITT_VIEW
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/28/2010    Chao Yu       1. Created this procedure.

 
******************************************************************************/
BEGIN
  

 
   
   EXECUTE IMMEDIATE 'Grant select on V_META_LOOKUP_SYSTEM_ROLES to KITT_META';
   EXECUTE IMMEDIATE 'Grant select on V_META_LOOKUP_USER_PROFILES to KITT_META';
   EXECUTE IMMEDIATE 'Grant select on V_META_CONTRACT to KITT_META';
   EXECUTE IMMEDIATE 'Grant select on V_META_VENDOR to KITT_META';
   EXECUTE IMMEDIATE 'Grant select on V_META_LOOKUP_USER_ROLE to KITT_META';
 
 
  
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_GRANT_KITT_META; 
/
