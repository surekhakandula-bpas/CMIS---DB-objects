DROP PACKAGE PK_REPORT_REFRESH;

CREATE OR REPLACE PACKAGE              "PK_REPORT_REFRESH" AS
/******************************************************************************
   NAME:       PK_RPT_REFRESH
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/10/2011      jgoff       1. Created this package.
******************************************************************************/


  PROCEDURE TOOL_PDF_CROSSCHECK;


END PK_REPORT_REFRESH;
/

DROP PACKAGE BODY PK_REPORT_REFRESH;

CREATE OR REPLACE PACKAGE BODY            "PK_REPORT_REFRESH" AS


PROCEDURE TOOL_PDF_CROSSCHECK IS

/******************************************************************************
   NAME:       P_UTI_PDF_CROSSCHECK
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/9/2011   jgoff       1. Created this procedure.
   1.1        10/28/2011 Jon Goff   1. Changed reference for env

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     P_UTI_PDF_CROSSCHECK
      Sysdate:         2/9/2011
      Date and Time:   2/9/2011, 12:38:17 PM, and 2/9/2011 12:38:17 PM
      Username:        jgoff (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/

LV_ICF_CHECK_CONDITION_LABEL    VARCHAR(500) := 'Searched for an ICF where Ownership of A/P or CO.';
LV_NPL_CHECK_CONDITION_LABEL    VARCHAR(500) := 'Searched for an NPL where Ownership of A/P and contains at least 1 invoice item as PMO disputed.'||
chr(10)||chr(10)||'Exceptions:  Suppress Problems when Ownership is CO (402)';
LV_NTP_CHECK_CONDITION_LABEL    VARCHAR(500) := 'Searched for an NTP where Ownership of CO, ACKNOWLEDGE, EXPIRED, or COMPLETED.';
LV_IVC_CHECK_CONDITION_LABEL    VARCHAR(500) := 'Searched for an IVC where the invoice has ANY status EXCEPT NEW.';
LV_TO_CHECK_CONDITION_LABEL     VARCHAR(500) := 'Searched for Task Orders where DSA is Locked or Ownership of TOM, ETO, CTR PM, CTR CO, COTR, CO, or -, and State of Active, Closed, or Revised.';
LV_TO_CLOSEOUT_CHECK_LABEL     VARCHAR(500) := 'Searched for Task Orders where DSA is Locked or Status of Closeout Initiated or Closeout Completed';


LV_PROBLEM_CNT                          NUMBER;
LV_ENV_NAME                             SYSTEM_PARAMETER.C_PAR_VALUE%TYPE;
LV_CHECK_MESSAGE_PROBLEMS   VARCHAR2(4000);
LV_REPORT_OUTPUT_URL            VARCHAR2(500);



BEGIN


     EXECUTE IMMEDIATE ('TRUNCATE TABLE UTL_TOOL_PDF_CROSSCHECK');

     LV_ENV_NAME := GET_ENV_NAME;

    --
    -- Initialize CROSSCHECK
    --
    INSERT INTO UTL_TOOL_PDF_CROSSCHECK
    (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    PDF_SIZE_ATTRIBUTE,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
    SELECT   C_OBJECT_TYPE,
                    'CONTRACT_DSA',
                    'C_OBJECT_TYPE',
                    C_OBJECT_TYPE,
                    'N_OBJECT_ID',
                    N_OBJECT_ID,
                    DECODE(C_OBJECT_TYPE, 'NTP','NTP',
                                                            'ICF','INVOICE_CERTIFICATION_LETTER',
                                                            'NPL','INVOICE_CERTIFICATION_LETTER',
                                                            'Invoice Voucher','INVOICE',
                                                            'Close Out','TASK_ORDER',
                                                            'UNKNOWN'),
                    DECODE(C_OBJECT_TYPE, 'NTP','N_NTP_ID',
                                                            'ICF','N_INVOICE_ID',
                                                            'NPL','N_INVOICE_ID',
                                                            'Invoice Voucher','N_INVOICE_ID',
                                                            'Close Out','N_TASK_ORDER_ID',
                                                            'UNKNOWN'),
                    N_OBJECT_ID,
                     DECODE(C_OBJECT_TYPE, 'NTP','NTP',
                                                            'ICF','ICF',
                                                            'NPL','NPL',
                                                            'Invoice Voucher','Invoice Voucher',
                                                            C_OBJECT_TYPE)||' '||N_OBJECT_ID||CHR(10)
                                                            ||'PDF Size '||dbms_lob.getlength(CONTRACT_DSA.B_PDF)||'B',
                    dbms_lob.getlength(CONTRACT_DSA.B_PDF),
                    'PROBLEMS',
                    'A PDF record for '||C_OBJECT_TYPE||
                    ' ID '||N_OBJECT_ID||' was found; however, the status of the record was not included in the defined crosscheck conditions.',
                    DECODE(C_OBJECT_TYPE, 'NTP',LV_NTP_CHECK_CONDITION_LABEL,
                                                           'ICF',LV_ICF_CHECK_CONDITION_LABEL,
                                                           'NPL',LV_NPL_CHECK_CONDITION_LABEL,
                                                           'Invoice Voucher',LV_IVC_CHECK_CONDITION_LABEL,
                                                           'Close Out',LV_TO_CLOSEOUT_CHECK_LABEL,
                                                           'Undefined'),
                    SYSDATE
      FROM CONTRACT_DSA;



 INSERT INTO UTL_TOOL_PDF_CROSSCHECK
        (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    PDF_SIZE_ATTRIBUTE,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
     SELECT   'TASK ORDER',
                    'CONTRACT_PDF',
                    'N_TASK_ORDER_ID',
                    N_TASK_ORDER_ID,
                    NULL,
                    NULL,
                    'TASK_ORDER',
                    'N_TASK_ORDER_ID',
                    N_TASK_ORDER_ID,
                    (SELECT 'Task Order '||TASK_ORDER.C_TASK_ORDER_NUMBER||CHR(10)||
                                'PDF Size '||dbms_lob.getlength(CONTRACT_PDF.B_CONTRACT)||'B'
                    FROM TASK_ORDER
                    WHERE TASK_ORDER.N_TASK_ORDER_ID = CONTRACT_PDF.N_TASK_ORDER_ID),
                    dbms_lob.getlength(CONTRACT_PDF.B_CONTRACT),
                    'PROBLEMS',
                    'A PDF record for Task Order '||(SELECT TASK_ORDER.C_TASK_ORDER_NUMBER
                                                                    FROM TASK_ORDER
                                                                    WHERE TASK_ORDER.N_TASK_ORDER_ID = CONTRACT_PDF.N_TASK_ORDER_ID)||
                                                                    ' was found; however, the status of the record was not included in the defined crosscheck conditions.',
                    LV_TO_CHECK_CONDITION_LABEL,
                    SYSDATE
      FROM CONTRACT_PDF;


    --
    --VERIFY PDFs
    --

    --ICF
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_STATUS = 'SUCCESSFUL',
            CHECK_MESSAGE = 'PDF Crosscheck conditions matched the ICF PDF record.',
             CHECK_CONDITION = LV_ICF_CHECK_CONDITION_LABEL
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'ICF'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID'
                  AND CHECK_VALUE2 IN (  SELECT N_INVOICE_ID
                                                         FROM INVOICE_CERTIFICATION_LETTER
                                                        WHERE N_OWNERSHIP_NUMBER IN (403, 402, 404)
                                                       );


    --NPL
    -- EXCEPTION: INCLUDE OWNERSHIP IN 402 CO (SUPPRESS CHECKS)
    UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_STATUS = 'SUCCESSFUL',
             CHECK_MESSAGE = 'PDF Crosscheck conditions matched the NPL PDF record.',
             CHECK_CONDITION = LV_NPL_CHECK_CONDITION_LABEL
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'NPL'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID'
                  AND CHECK_VALUE2 IN (  SELECT N_INVOICE_ID
                                                        FROM INVOICE_CERTIFICATION_LETTER
                                                        WHERE INVOICE_CERTIFICATION_LETTER.N_OWNERSHIP_NUMBER IN (402, 403, 404)
                                                                    AND INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID IN
                                                                        (SELECT INVOICE_ITEM.N_INVOICE_ID
                                                                         FROM INVOICE_ITEM
                                                                         WHERE INVOICE_ITEM.F_PMO_DISPUTE_FLAG = 'Y')
                                                                         );


    --NTP
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_STATUS = 'SUCCESSFUL',
             CHECK_MESSAGE = 'PDF Crosscheck conditions matched the NTP PDF record.',
             CHECK_CONDITION = LV_NTP_CHECK_CONDITION_LABEL
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'NTP'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID'
                  AND CHECK_VALUE2 IN (SELECT N_NTP_ID
                                                      FROM NTP
                                                      WHERE N_OWNERSHIP_NUMBER IN (204, 205, 206, 207)
                                                        );



      --INVOICE VOUCHER
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_STATUS = 'SUCCESSFUL',
             CHECK_MESSAGE = 'PDF Crosscheck conditions matched the Invoice Voucher PDF record.',
             CHECK_CONDITION = LV_IVC_CHECK_CONDITION_LABEL
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'Invoice Voucher'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID'
                  AND CHECK_VALUE2 IN (SELECT N_INVOICE_ID
                                                      FROM INVOICE
                                                      WHERE N_STATUS_NUMBER != 300
                                                      );


      --TASK ORDER
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_STATUS = 'SUCCESSFUL',
             CHECK_MESSAGE = 'PDF Crosscheck conditions matched the Task Order PDF record.',
             CHECK_CONDITION = LV_TO_CHECK_CONDITION_LABEL
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_PDF'
                  AND CHECK_IDENTIFIER1 = 'N_TASK_ORDER_ID'
                  AND CHECK_VALUE1 IN (SELECT TASK_ORDER.N_TASK_ORDER_ID
                                                     FROM TASK_ORDER, SUB_TASK_ORDER
                                                    WHERE TASK_ORDER.N_TASK_ORDER_ID = SUB_TASK_ORDER.N_TASK_ORDER_ID
                                                            AND TASK_ORDER.N_STATE_NUMBER IN (101, 103, 104, 107)
                                                            AND TASK_ORDER.N_OWNERSHIP_NUMBER IN (103, 104, 105, 106, 107, 108, 109, 110, 500, 501, 502, 503, 504, 505, 506, 507)
                                                      );



      --TASK ORDER CLOSEOUT
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_STATUS = 'SUCCESSFUL',
             CHECK_MESSAGE = 'PDF Crosscheck conditions matched the Task Order PDF record.',
             CHECK_CONDITION = LV_TO_CLOSEOUT_CHECK_LABEL
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'Close Out'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID'
                  AND CHECK_VALUE2 IN (SELECT TASK_ORDER.N_TASK_ORDER_ID
                                                     FROM TASK_ORDER, SUB_TASK_ORDER
                                                    WHERE TASK_ORDER.N_TASK_ORDER_ID = SUB_TASK_ORDER.N_TASK_ORDER_ID
                                                            AND TASK_ORDER.N_STATUS_NUMBER IN (501, 502)
                                                      );


    --
    -- CHECK MISSING PDFs
    --


   --CHECK MISSING ICF PDFs
    INSERT INTO UTL_TOOL_PDF_CROSSCHECK
       (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
    SELECT 'ICF',
          'CONTRACT_DSA',
          'C_OBJECT_TYPE',
          'ICF',
          'N_OBJECT_ID',
          INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID,
          'INVOICE_CERTIFICATION_LETTER',
          'N_INVOICE_ID',
          INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID,
          'ICF '||INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID,
          'PROBLEMS',
          'Unable to find an ICF PDF record for invoice ' || INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID||'.',
          LV_ICF_CHECK_CONDITION_LABEL,
          SYSDATE
     FROM INVOICE_CERTIFICATION_LETTER
     WHERE INVOICE_CERTIFICATION_LETTER.N_OWNERSHIP_NUMBER IN (403, 402, 404)
          AND INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID NOT IN
                 (SELECT N_OBJECT_ID
                    FROM CONTRACT_DSA
                   WHERE C_OBJECT_TYPE = 'ICF');


     --CHECK MISSING NPL PDFs
     -- EXCEPTION: EXCLUDE OWNERSHIP IN 402 CO (SUPPRESS CHECKS)
     INSERT INTO UTL_TOOL_PDF_CROSSCHECK
        (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
    SELECT   'NPL',
          'CONTRACT_DSA',
          'C_OBJECT_TYPE',
          'NPL',
          'N_OBJECT_ID',
          INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID,
          'INVOICE_CERTIFICATION_LETTER',
          'N_INVOICE_ID',
          INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID,
           'NPL '||INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID,
          'PROBLEMS',
          'Unable to find an NPL PDF record for invoice '  || INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID||'.',
          LV_NPL_CHECK_CONDITION_LABEL,
          SYSDATE
     FROM INVOICE_CERTIFICATION_LETTER
    WHERE INVOICE_CERTIFICATION_LETTER.N_OWNERSHIP_NUMBER IN (403, 404)
          AND INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID IN
                 (SELECT INVOICE_ITEM.N_INVOICE_ID
                    FROM INVOICE_ITEM
                   WHERE INVOICE_ITEM.F_PMO_DISPUTE_FLAG = 'Y')
          AND INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID NOT IN
                 (SELECT N_OBJECT_ID
                    FROM CONTRACT_DSA
                   WHERE C_OBJECT_TYPE = 'NPL');



      --CHECK MISSING NTP PDFs
      INSERT INTO UTL_TOOL_PDF_CROSSCHECK
         (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
      SELECT   'NTP',
                    'CONTRACT_DSA',
                    'C_OBJECT_TYPE',
                    'NTP',
                    'N_OBJECT_ID',
                    NTP.N_NTP_ID,
                    'NTP',
                    'N_NTP_ID',
                    NTP.N_NTP_ID,
                    'NTP '||NTP.N_NTP_ID,
                    'PROBLEMS',
                    'Unable to find a PDF record for NTP ' || NTP.N_NTP_ID || ' ' || NTP.C_PR_NUMBER||'.',
                    LV_NTP_CHECK_CONDITION_LABEL,
                    SYSDATE
       FROM NTP
       WHERE N_OWNERSHIP_NUMBER IN (204, 205, 206, 207)
                   AND NTP.N_NTP_ID NOT IN (SELECT CONTRACT_DSA.N_OBJECT_ID
                                                            FROM CONTRACT_DSA
                                                            WHERE CONTRACT_DSA.C_OBJECT_TYPE = 'NTP') ;



      --CHECK MISSING Invoice Voucher PDFs
       INSERT INTO UTL_TOOL_PDF_CROSSCHECK
          (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
      SELECT 'Invoice Voucher',
       'CONTRACT_DSA',
          'C_OBJECT_TYPE',
          'Invoice Voucher',
          'N_OBJECT_ID',
           INVOICE.N_INVOICE_ID,
          'INVOICE',
          'N_INVOICE_ID',
          INVOICE.N_INVOICE_ID,
          'Invoice Voucher '||INVOICE.N_INVOICE_ID,
          'PROBLEMS',
          'Unable to find an Invoice Voucher PDF record for invoice '  || INVOICE.N_INVOICE_ID||'.',
          LV_IVC_CHECK_CONDITION_LABEL,
          SYSDATE
     FROM INVOICE
    WHERE N_STATUS_NUMBER != 300
          AND INVOICE.N_INVOICE_ID NOT IN
                 (SELECT CONTRACT_DSA.N_OBJECT_ID
                    FROM CONTRACT_DSA
                   WHERE CONTRACT_DSA.C_OBJECT_TYPE = 'Invoice Voucher');


     --CHECK MISSING TASK ORDER PDFs
    INSERT INTO UTL_TOOL_PDF_CROSSCHECK
       (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
    SELECT DISTINCT
          'TASK ORDER',
          'CONTRACT_PDF',
          'N_TASK_ORDER_ID',
          TASK_ORDER.N_TASK_ORDER_ID,
          NULL,
          NULL,
          'TASK_ORDER',
          'N_TASK_ORDER_ID',
          TASK_ORDER.N_TASK_ORDER_ID,
          'Task Order '||TASK_ORDER.C_TASK_ORDER_NUMBER,
          'PROBLEMS',
          'Unable to find a PDF record for Task Order ' || TASK_ORDER.C_TASK_ORDER_NUMBER||'.',
          LV_TO_CHECK_CONDITION_LABEL,
          SYSDATE
     FROM TASK_ORDER, SUB_TASK_ORDER
    WHERE TASK_ORDER.N_TASK_ORDER_ID = SUB_TASK_ORDER.N_TASK_ORDER_ID
          AND (
                    TASK_ORDER.N_STATE_NUMBER IN (103, 104, 107) -- removed draft check but included check for dsa locked
                    AND TASK_ORDER.N_OWNERSHIP_NUMBER IN
                         (103, 104, 105, 106, 107, 108, 109, 110, 500, 501, 502, 503, 504, 505, 506, 507)
                    AND TASK_ORDER.N_TASK_ORDER_ID NOT IN
                        (SELECT CONTRACT_PDF.N_TASK_ORDER_ID FROM CONTRACT_PDF)
                    ) OR
                    (
                    TASK_ORDER.F_DSA_LOCKED = 'Y'
                    AND TASK_ORDER.N_TASK_ORDER_ID NOT IN
                        (SELECT CONTRACT_PDF.N_TASK_ORDER_ID FROM CONTRACT_PDF)
                     );



     --CHECK MISSING TASK ORDER CLOSEOUT PDFs
    INSERT INTO UTL_TOOL_PDF_CROSSCHECK
       (CHECK_LABEL,
    CHECK_TARGET_TABLE,
    CHECK_IDENTIFIER1,
    CHECK_VALUE1,
    CHECK_IDENTIFIER2,
    CHECK_VALUE2,
    SOURCE_TABLE,
    SOURCE_IDENTIFIER1,
    SOURCE_VALUE1,
    SOURCE_DESCR,
    CHECK_STATUS,
    CHECK_MESSAGE,
    CHECK_CONDITION,
    ANALYSIS_TIMESTAMP)
    SELECT DISTINCT
          'TASK ORDER',
          'CONTRACT_DSA',
          'C_OBJECT_TYPE',
          'Close Out',
          'N_OBJECT_ID',
          TASK_ORDER.N_TASK_ORDER_ID,
          'TASK_ORDER',
          'N_TASK_ORDER_ID',
          TASK_ORDER.N_TASK_ORDER_ID,
          'Task Order '||TASK_ORDER.C_TASK_ORDER_NUMBER,
          'PROBLEMS',
          'Unable to find a PDF record for Task Order ' || TASK_ORDER.C_TASK_ORDER_NUMBER||'.',
          LV_TO_CLOSEOUT_CHECK_LABEL,
          SYSDATE
     FROM TASK_ORDER, SUB_TASK_ORDER
    WHERE TASK_ORDER.N_TASK_ORDER_ID = SUB_TASK_ORDER.N_TASK_ORDER_ID
          AND TASK_ORDER.N_STATUS_NUMBER IN
                 (501, 502)
          AND TASK_ORDER.N_TASK_ORDER_ID NOT IN
                 (SELECT CONTRACT_DSA.N_OBJECT_ID
                                                            FROM CONTRACT_DSA
                                                            WHERE CONTRACT_DSA.C_OBJECT_TYPE = 'Close Out');





      --
      -- INCLUDE ADDITIONAL INFORMATION
      --

      --ICF
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_CONDITION = CHECK_CONDITION||CHR(10)||CHR(10)||NVL(
                                              (SELECT 'Actual: Ownership is '||OWNERSHIP.C_OWNERSHIP_LABEL||' ('||OWNERSHIP.N_OWNERSHIP_NUMBER||').'
                                              FROM INVOICE_CERTIFICATION_LETTER, OWNERSHIP
                                              WHERE INVOICE_CERTIFICATION_LETTER.N_OWNERSHIP_NUMBER = OWNERSHIP.N_OWNERSHIP_NUMBER
                                                        AND CHECK_VALUE2 = N_INVOICE_ID
                                                        )
                                                           , 'Actual: Ownership status is missing.')
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'ICF'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID';



    --NPL
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_CONDITION = CHECK_CONDITION||CHR(10)||CHR(10)||NVL(
                                               (SELECT 'Actual: Ownership is '||OWNERSHIP.C_OWNERSHIP_LABEL||' ('||OWNERSHIP.N_OWNERSHIP_NUMBER||') with disputed invoice item.'
                                              FROM INVOICE_CERTIFICATION_LETTER, OWNERSHIP
                                              WHERE INVOICE_CERTIFICATION_LETTER.N_OWNERSHIP_NUMBER = OWNERSHIP.N_OWNERSHIP_NUMBER
                                                        AND CHECK_VALUE2 = N_INVOICE_ID
                                                        AND INVOICE_CERTIFICATION_LETTER.N_INVOICE_ID IN
                                                                        (SELECT INVOICE_ITEM.N_INVOICE_ID
                                                                         FROM INVOICE_ITEM
                                                                         WHERE INVOICE_ITEM.F_PMO_DISPUTE_FLAG = 'Y')
                                                )
                                                 , 'Actual: Ownership status is missing or disputed invoice item is missing.')
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'NPL'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID';




      --NTP
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_CONDITION = CHECK_CONDITION||CHR(10)||CHR(10)||NVL(
                                               (SELECT 'Actual: Ownership is '||OWNERSHIP.C_OWNERSHIP_LABEL||' ('||OWNERSHIP.N_OWNERSHIP_NUMBER||').'
                                               FROM NTP, OWNERSHIP
                                               WHERE NTP.N_OWNERSHIP_NUMBER = OWNERSHIP.N_OWNERSHIP_NUMBER
                                                        AND CHECK_VALUE2 = N_NTP_ID
                                                        )
                                                        , 'Actual: Ownership status is missing.')
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'NTP'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID';




      --INVOICE VOUCHER
      UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_CONDITION = CHECK_CONDITION||CHR(10)||CHR(10)||NVL(
                                                    (SELECT 'Actual: Status is '||STATUS.C_STATUS_LABEL||' ('||STATUS.N_STATUS_NUMBER||').'
                                                      FROM INVOICE, STATUS
                                                      WHERE INVOICE.N_STATUS_NUMBER = STATUS.N_STATUS_NUMBER
                                                                AND CHECK_VALUE2 = INVOICE.N_INVOICE_ID
                                                      )
                                                      , 'Actual: Status is missing.')
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'Invoice Voucher'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID';



    --TASK ORDER
    UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_CONDITION =  CHECK_CONDITION||CHR(10)||CHR(10)||NVL(
                                                        (SELECT 'Actual: State is '||STATE.C_STATE_LABEL||' ('||STATE.N_STATE_NUMBER||') and Ownership is '
                                                        ||OWNERSHIP.C_OWNERSHIP_LABEL||' ('||OWNERSHIP.N_OWNERSHIP_NUMBER||') and DSA is '||DECODE(TASK_ORDER.F_DSA_LOCKED,'Y','Locked','N','Unlocked','Unspecified')
                                                        FROM TASK_ORDER, STATE, OWNERSHIP
                                                        WHERE TASK_ORDER.N_STATE_NUMBER = STATE.N_STATE_NUMBER
                                                                    AND TASK_ORDER.N_OWNERSHIP_NUMBER = OWNERSHIP.N_OWNERSHIP_NUMBER
                                                                    AND CHECK_VALUE1 = TASK_ORDER.N_TASK_ORDER_ID
                                                           )
                                                           ,  'Actual: State or Ownership is missing.')
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_PDF'
                  AND CHECK_IDENTIFIER1 = 'N_TASK_ORDER_ID';



   --TASK ORDER CLOSEOUT
    UPDATE UTL_TOOL_PDF_CROSSCHECK
      SET CHECK_CONDITION =  CHECK_CONDITION||CHR(10)||CHR(10)||NVL(
                                                        (SELECT 'Actual: State is '||STATE.C_STATE_LABEL||' ('||STATE.N_STATE_NUMBER||') and Ownership is '
                                                        ||OWNERSHIP.C_OWNERSHIP_LABEL||' ('||OWNERSHIP.N_OWNERSHIP_NUMBER||') and Status is '||STATUS.C_STATUS_LABEL||' ('||STATUS.N_STATUS_NUMBER||')'||
                                                        ' and DSA is '||DECODE(TASK_ORDER.F_DSA_LOCKED,'Y','Locked','N','Unlocked','Unspecified')
                                                        FROM TASK_ORDER, STATE, STATUS, OWNERSHIP
                                                        WHERE TASK_ORDER.N_STATE_NUMBER = STATE.N_STATE_NUMBER
                                                                    AND TASK_ORDER.N_STATUS_NUMBER = STATUS.N_STATUS_NUMBER
                                                                    AND TASK_ORDER.N_OWNERSHIP_NUMBER = OWNERSHIP.N_OWNERSHIP_NUMBER
                                                                    AND CHECK_VALUE2 = TASK_ORDER.N_TASK_ORDER_ID
                                                           )
                                                           ,  'Actual: State or Ownership or Status is missing.')
      WHERE CHECK_TARGET_TABLE = 'CONTRACT_DSA'
                  AND CHECK_IDENTIFIER1 = 'C_OBJECT_TYPE'
                  AND CHECK_VALUE1 = 'Close Out'
                  AND CHECK_IDENTIFIER2 = 'N_OBJECT_ID';




    --
    -- Check PDF byte size
    --
     UPDATE UTL_TOOL_PDF_CROSSCHECK
     SET CHECK_STATUS = 'PROBLEMS',
            CHECK_MESSAGE =  CHECK_MESSAGE||CHR(10)||'PDF data size is questionable.'
      WHERE  PDF_SIZE_ATTRIBUTE < 30000;

     UPDATE UTL_TOOL_PDF_CROSSCHECK
     SET CHECK_STATUS = 'PROBLEMS',
            CHECK_MESSAGE =  CHECK_MESSAGE||CHR(10)||CHR(10)||'No PDF data stored.'
      WHERE PDF_SIZE_ATTRIBUTE IS NULL;


    --
    -- ACHKNOWLEDGE PROBLEMS
    --
    UPDATE UTL_TOOL_PDF_CROSSCHECK
    SET UTL_TOOL_PDF_CROSSCHECK.CHECK_STATUS = 'PROBLEMS ACKNOWLEDGED'
    WHERE UTL_TOOL_PDF_CROSSCHECK.CHECK_LABEL||
    UTL_TOOL_PDF_CROSSCHECK.CHECK_TARGET_TABLE||
    UTL_TOOL_PDF_CROSSCHECK.CHECK_IDENTIFIER1||
    UTL_TOOL_PDF_CROSSCHECK.CHECK_VALUE1||
    UTL_TOOL_PDF_CROSSCHECK.CHECK_IDENTIFIER2||
    UTL_TOOL_PDF_CROSSCHECK.CHECK_VALUE2 = ( SELECT CHECK_LABEL||
                                                                                    CHECK_TARGET_TABLE||
                                                                                    CHECK_IDENTIFIER1||
                                                                                    CHECK_VALUE1||
                                                                                    CHECK_IDENTIFIER2||
                                                                                    CHECK_VALUE2
                                                                           FROM UTL_TOOL_PDF_CROSSCHECK_AKNLG);

    --COMMIT CHANGES
    COMMIT;

   SELECT COUNT(*)
   INTO LV_PROBLEM_CNT
   FROM UTL_TOOL_PDF_CROSSCHECK
   WHERE CHECK_STATUS = 'PROBLEMS';

   SELECT WM_CONCAT('Problem '||rownum||':<br>'||CHECK_MESSAGE||'  Extended Message: '||CHECK_CONDITION||'<br><br>')
   INTO LV_CHECK_MESSAGE_PROBLEMS
   FROM UTL_TOOL_PDF_CROSSCHECK
   WHERE CHECK_STATUS = 'PROBLEMS'
            AND ROWNUM <= 6;


   LV_CHECK_MESSAGE_PROBLEMS := replace(LV_CHECK_MESSAGE_PROBLEMS,',Problem','Problem');

   --Limit messages in alert
   IF LV_PROBLEM_CNT > 6 THEN
         LV_CHECK_MESSAGE_PROBLEMS := 'Check Messages exceed message limit of 6.  All of the PDF problems are not reported here.  Check the PDF Crosscheck Report for a complete list of problems.'||
                                                '<br><br><br>'||LV_CHECK_MESSAGE_PROBLEMS;
   END IF;


    --
    -- SEND NOTIFICATIONS ON PROBLEMS
    --
   IF LV_PROBLEM_CNT > 0 THEN

          PK_EMAIL.SEND_EMAIL_DISTRIBUTION ('jon.ctr.goff@faa.gov',
                                                    'ALERT_TECH',
                                                    'PDF Crosscheck Detected Problems',
                                                    'Please check the latest <a href="'||LV_REPORT_OUTPUT_URL||'">PDF Crosscheck Report</a> that was ran after the timestamp of this alert.'||
                                                    '<br><br>'||
                                                    LV_CHECK_MESSAGE_PROBLEMS
                                                    );

          PK_TOOLS.SEND_KITT_LOG (101,
                                                 'PDF Crosscheck',
                                                 'PK_REPORT_REFRESH.TOOL_PDF_CROSSCHECK',
                                                 'ERROR',
                                                 'PDF Crosscheck Detected Problems',
                                                 LV_CHECK_MESSAGE_PROBLEMS,
                                                 NULL);

    ELSE

          --
          -- Send email with report link
          --
          PK_EMAIL.SEND_EMAIL_DISTRIBUTION ('jon.ctr.goff@faa.gov',
                                                    'ALERT_TECH',
                                                    'PDF Crosscheck Successful',
                                                    'PDF Crosscheck found no PDF problems.  A copy of the <a href="'||LV_REPORT_OUTPUT_URL||'">report</a> is now available to view.'||
                                                    '<br><br>'
                                                    );
    END IF;




   EXCEPTION
     WHEN OTHERS THEN

       PK_EMAIL.SEND_EMAIL_DISTRIBUTION ('jon.ctr.goff@faa.gov',
                                            'ALERT_TECH',
                                            'PDF Crosscheck Database Job Failed',
                                            'Unable to gather data for the PDF Crosscheck status.'||
                                            '<br><br>'||
                                            SQLERRM||
                                            '<br><br>'
                                            );
       RAISE;

END TOOL_PDF_CROSSCHECK;


END PK_REPORT_REFRESH;
/
