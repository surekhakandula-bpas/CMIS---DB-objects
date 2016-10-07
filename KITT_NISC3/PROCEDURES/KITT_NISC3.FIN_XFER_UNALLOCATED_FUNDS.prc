DROP PROCEDURE FIN_XFER_UNALLOCATED_FUNDS;

CREATE OR REPLACE PROCEDURE            FIN_XFER_UNALLOCATED_FUNDS (
                                                         MY_OLD_ETO_ID    IN NUMBER,
                                                         MY_NEW_ETO_ID    IN NUMBER,
                                                         MY_USER_ID       IN NUMBER,
                                                         MY_STATUS       OUT VARCHAR2,
                                                         MY_MSG          OUT VARCHAR2)


IS

/******************************************************************************
   NAME:       FIN_XFER_UNALLOCATED_FUNDS
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/15/2010    Chao Yu      1. Created this procedure.

   NOTES:

   This procedure will tranfer all un-allocated delphi line balance
   from one OLD ETO to NEW ETO

******************************************************************************/


BEGIN

     PK_FINANCE.FIN_XFER_UNALLOCATED_FUNDS (
                                  MY_OLD_ETO_ID,
                                  MY_NEW_ETO_ID,
                                  MY_USER_ID,
                                  MY_STATUS,
                                  MY_MSG);


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END FIN_XFER_UNALLOCATED_FUNDS;
/
