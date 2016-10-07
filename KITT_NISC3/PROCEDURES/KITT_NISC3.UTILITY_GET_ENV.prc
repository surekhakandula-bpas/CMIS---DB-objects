DROP PROCEDURE UTILITY_GET_ENV;

CREATE OR REPLACE PROCEDURE            "UTILITY_GET_ENV" (ENV_NAME out varchar2)
IS
/******************************************************************************
   NAME:       UTILITY_GET_ENV
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/24/2009   Chao       1. Created this procedure.
   1.1        10/2/2011   Jon Goff    1. Changed reference for env

   NOTES:
   Get environmnet name. Like KITTS_DEV, KITT_TEST, KITT_BETA and KITT_PROD

******************************************************************************/

Curr_env  SYSTEM_PARAMETER.C_PAR_VALUE%TYPE;

BEGIN

   select C_PAR_VALUE
   into Curr_env
   from SYSTEM_PARAMETER
   where C_PAR_NAME = 'env_des';

    ENV_NAME:=Curr_env;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END UTILITY_GET_ENV;
/
