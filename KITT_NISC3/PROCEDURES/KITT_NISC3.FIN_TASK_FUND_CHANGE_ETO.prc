DROP PROCEDURE FIN_TASK_FUND_CHANGE_ETO;

CREATE OR REPLACE PROCEDURE            FIN_TASK_FUND_CHANGE_ETO ( MY_TASK_ORDER_ID IN NUMBER,
                                                                 MY_OLD_ETO_ID    IN NUMBER,
                                                                 MY_NEW_ETO_ID    IN NUMBER,
                                                                 MY_LOGINUSER_ID  IN NUMBER,
                                                                 MY_STATUS       OUT VARCHAR2,
                                                                 MY_MSG          OUT VARCHAR2)


 IS

/******************************************************************************
   NAME:       FIN_TASK_FUND_CHANGE_ETO
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        09/15/2010     Chao Yu     1. Created this procedure.

   NOTES:

   This procedure will handle funding transter from old ETO to new ETO
   changing the task order ETO.
******************************************************************************/



BEGIN


   PK_FINANCE.FIN_TASK_FUND_CHANGE_ETO ( MY_TASK_ORDER_ID,
                                         MY_OLD_ETO_ID,
                                         MY_NEW_ETO_ID,
                                         MY_LOGINUSER_ID,
                                         MY_STATUS,
                                         MY_MSG );


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END FIN_TASK_FUND_CHANGE_ETO;
/
