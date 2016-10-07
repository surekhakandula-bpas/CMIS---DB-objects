DROP FUNCTION GET_ENV_NAME;

CREATE OR REPLACE FUNCTION            "GET_ENV_NAME" RETURN varchar2 IS

/******************************************************************************
   NAME:       GET_ENV_NAME
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/7/2010    Chao Yu      1. Created this function.
   1.1         10/28/2011 Jon Goff     1. Modified to reference new source for env
   NOTES:

    Return the database environment name
******************************************************************************/
MyName SYSTEM_PARAMETER.C_PAR_VALUE%TYPE;

BEGIN

   select C_PAR_VALUE
   into MyName
   from SYSTEM_PARAMETER
   where C_PAR_NAME = 'env_des';

   RETURN MyName;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       RETURN MyName;
     WHEN OTHERS THEN
       RETURN MyName;
       RAISE;
END GET_ENV_NAME;
/
