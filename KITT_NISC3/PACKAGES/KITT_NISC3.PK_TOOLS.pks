DROP PACKAGE PK_TOOLS;

CREATE OR REPLACE PACKAGE            "PK_TOOLS" AS

/******************************************************************************
   NAME:       PK_TOOLS
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------

   1.0        10/18/2011    Jon Goff                           2. Included action item purge routine

******************************************************************************/

   PROCEDURE PURGE_ACTION_ITEMS;
   PROCEDURE SEND_KITT_LOG (P_CONTRACT_ID IN NUMBER,
                                                      P_PROGRAM_NAME IN VARCHAR2,
                                                      P_MODULE_NAME IN VARCHAR2,
                                                      P_LOG_CATEGORY IN VARCHAR2,
                                                      P_MESSAGE IN VARCHAR2,
                                                      P_DESCRIPTION IN VARCHAR2,
                                                      P_STACKTRACE IN VARCHAR2);

END PK_TOOLS;
/

DROP PACKAGE BODY PK_TOOLS;

CREATE OR REPLACE PACKAGE BODY            "PK_TOOLS" AS

/******************************************************************************
   NAME:       PK_TOOLS
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------

   1.0        10/18/2011    Jon Goff                           2. Included action item purge routine

******************************************************************************/


   PROCEDURE PURGE_ACTION_ITEMS IS
    lv_rc                                    NUMBER;

   BEGIN

       --
       --Remove action item recipients
       --
       DELETE FROM ACTION_ITEM_RECEIVER AIR
       WHERE AIR.N_ACTION_ITEM_RECEIVER_ID IN (SELECT VKAI.N_ACTION_ITEM_RECEIVER_ID
                                                          FROM V_KITTV_ACTION_ITEM VKAI
                                                          WHERE VKAI.D_EXPIRE_DATE < SYSDATE-1);
       lv_rc := SQL%ROWCOUNT;

       PK_TOOLS.SEND_KITT_LOG (101,
                                                 'Purge Action Item by Recipient',
                                                 'PK_TOOLS.PURGE_ACTION_ITEMS',
                                                 'INFO',
                                                 'Purge Action Items processed '||lv_rc||' records.',
                                                 'Purge all action items outside of the Action Item Retention Policy period.',
                                                 NULL);

       --
       --Remove obsolete action items
       --
       DELETE FROM ACTION_ITEM AI
       WHERE AI.N_ACTION_ITEM_ID NOT IN (SELECT AIR.N_ACTION_ITEM_ID
                                                                FROM ACTION_ITEM_RECEIVER AIR);

       lv_rc := SQL%ROWCOUNT;

       PK_TOOLS.SEND_KITT_LOG (101,
                                                 'Purge Obsolete Action Items',
                                                 'PK_TOOLS.PURGE_ACTION_ITEMS',
                                                 'INFO',
                                                 'Purge Action Items processed '||lv_rc||' records.',
                                                 'Purge all obsolete action items.',
                                                 NULL);
      COMMIT;


       EXCEPTION
        WHEN OTHERS THEN

                PK_TOOLS.SEND_KITT_LOG (101,
                                                 'Purge Action Items',
                                                 'PK_TOOLS.PURGE_ACTION_ITEMS',
                                                 'ERROR',
                                                 'Unable to complete the job.',
                                                 SQLERRM,
                                                 NULL);

                PK_EMAIL.SEND_EMAIL_DISTRIBUTION ('KITT System',
                                                    'ALERT_TECH',
                                                    'Purge Action Items Database Job Failed',
                                                    'Unable to complete the job.'||
                                                    '<br><br>'||
                                                    SQLERRM||
                                                    '<br><br>'
                                                    );

       RAISE;

   END PURGE_ACTION_ITEMS;


   PROCEDURE SEND_KITT_LOG (P_CONTRACT_ID IN NUMBER,
                                                      P_PROGRAM_NAME IN VARCHAR2,
                                                      P_MODULE_NAME IN VARCHAR2,
                                                      P_LOG_CATEGORY IN VARCHAR2,
                                                      P_MESSAGE IN VARCHAR2,
                                                      P_DESCRIPTION IN VARCHAR2,
                                                      P_STACKTRACE IN VARCHAR2) IS
                                                      PRAGMA AUTONOMOUS_TRANSACTION;

   BEGIN

   INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          P_CONTRACT_ID,
          P_PROGRAM_NAME,
          P_MODULE_NAME,
          P_LOG_CATEGORY,
          P_MESSAGE,
          P_DESCRIPTION,
          P_STACKTRACE,
          SYSTIMESTAMP
           );
     COMMIT;

    EXCEPTION
    WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR (-20102, 'Error processing log entry for KITT Log. Program SEND_KITT_LOG.  '||SQLERRM);

END SEND_KITT_LOG;

END PK_TOOLS;
/
