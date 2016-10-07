DROP FUNCTION IS_DEFAULT_ROLE;

CREATE OR REPLACE FUNCTION "IS_DEFAULT_ROLE" 
    (USER_ID NUMBER) RETURN CHAR IS
roleFlag CHAR(1);
/******************************************************************************
   NAME:       IS_DEFAULT_ROLE
   PURPOSE:  
   
    RETURNS 'Y' IF THE USER HAS NO PENDING OR APPROVED ROLES SET
    TO DEFAULT, OTHERWISE RETURNS 'N'  

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        10/20/2010   TAWFIQ DIAB       1. Created this function.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     IS_DEFAULT_ROLE
      Sysdate:         10/20/2010
      Date and Time:   10/20/2010, 11:58:59 AM, and 10/20/2010 11:58:59 AM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
defaultRoleCount number;

BEGIN
   
   roleFlag             := 'N';
   defaultRoleCount     :=  0;
    
    SELECT COUNT(*) INTO defaultRoleCount 
    FROM USER_ROLE 
    WHERE N_USER_PROFILE_ID = USER_ID
    AND UPPER(C_ROLE_STATUS) IN('PENDING','APPROVED')
    AND UPPER(F_DEFAULT_ROLE) = 'Y';
   
    IF  (defaultRoleCount = 0) THEN 
        roleFlag := 'Y';
    END IF;
    
   RETURN roleFlag;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RETURN roleFlag;
       RAISE;
END IS_DEFAULT_ROLE;
/
