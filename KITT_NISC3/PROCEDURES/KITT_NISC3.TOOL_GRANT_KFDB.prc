DROP PROCEDURE TOOL_GRANT_KFDB;

CREATE OR REPLACE PROCEDURE                TOOL_GRANT_KFDB IS

/******************************************************************************
   NAME:       TOOL_GRANT_KFDBUSER
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/28/2010   Chao Yu       1. Created this procedure.

   NOTES:

  

******************************************************************************/
BEGIN
   
   EXECUTE IMMEDIATE 'Grant select on V_KITTKFDB_PMO_EMAILS to KITT_KFDB';


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_GRANT_KFDB; 
/
