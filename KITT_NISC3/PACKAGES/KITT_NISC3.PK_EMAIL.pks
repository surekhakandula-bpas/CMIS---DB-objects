DROP PACKAGE PK_EMAIL;

CREATE OR REPLACE PACKAGE              "PK_EMAIL" AS
/******************************************************************************
   NAME:       PK_EMAIL
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/16/2011      jgoff       1. Created this package.
******************************************************************************/
PROCEDURE SEND_EMAIL_MESSAGE (
                                       P_SENDER     IN VARCHAR2,
                                       P_RECEIVER   IN   VARCHAR2,
                                       P_SUBJECT    IN   VARCHAR2,
                                       P_MESSAGE    IN   VARCHAR2);

  PROCEDURE SEND_EMAIL_DISTRIBUTION (
                                       P_SENDER             IN VARCHAR2,
                                       P_DISTRIBUTION   IN   VARCHAR2,
                                       P_SUBJECT            IN   VARCHAR2,
                                       P_MESSAGE            IN   VARCHAR2);

END PK_EMAIL;
/

DROP PACKAGE BODY PK_EMAIL;

CREATE OR REPLACE PACKAGE BODY            "PK_EMAIL" AS
/******************************************************************************
   NAME:       PK_EMAIL
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/16/2011      jgoff       1. Created this package body.
   1.1      04/13/2011  Jon Goff      1.  Added final exception
   1.2      10/20/2011  Jon Goff       1. Changed source on environment identifier

******************************************************************************/

PROCEDURE SEND_EMAIL_MESSAGE (
                                       P_SENDER     IN VARCHAR2,
                                       P_RECEIVER   IN   VARCHAR2,
                                       P_SUBJECT    IN   VARCHAR2,
                                       P_MESSAGE    IN   VARCHAR2)
IS

CONN                           UTL_SMTP.connection;
--CRLF                            VARCHAR2 (30)        := '<br><br>';
CRLF                            VARCHAR2 (30)        := chr(10);
MSG_WRAPPER             VARCHAR2 (4000);

BEGIN


   conn := UTL_SMTP.open_connection ('204.108.10.6', 25);
   UTL_SMTP.helo (CONN, '204.108.10.6');

   UTL_SMTP.mail (CONN, P_SENDER);
   UTL_SMTP.rcpt (CONN, P_RECEIVER);

   MSG_WRAPPER := 'Content-Type: text/html; charset="US-ASCII" '||
         'Date: '
      || TO_CHAR (SYSDATE, 'dd Mon yyyy hh24:mi:ss')
      || CRLF
      || 'From: KITT System'
      || CRLF
      || 'Subject: '
      || P_SUBJECT
      || CRLF
      || 'To: '
      || P_RECEIVER
      || CRLF
      || 'This message was sent by KITT''s automatic mailer.<br>'
      || CRLF
      || '====================================================<br><br>'
      || CRLF
      || CRLF
      || CRLF
      || P_MESSAGE
      || CRLF
      || CRLF
      || CRLF ||'<br><br>'
      || '====================================================<br>';


   UTL_SMTP.DATA (CONN, MSG_WRAPPER);
   UTL_SMTP.quit (CONN);


  EXCEPTION
    WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR (-20101, 'Error processing email distribution.');

END;



PROCEDURE SEND_EMAIL_DISTRIBUTION (
                                       P_SENDER     IN VARCHAR2,
                                       P_DISTRIBUTION   IN   VARCHAR2,
                                       P_SUBJECT    IN   VARCHAR2,
                                       P_MESSAGE    IN   VARCHAR2)
IS

    e_msg_exceeds_length           EXCEPTION;

    lv_env_name                         SYSTEM_PARAMETER.C_PAR_VALUE%TYPE;
    lv_env_location_msg              VARCHAR2(500);
    lv_msg                                  KITT_LOG.C_DESCRIPTION%TYPE;


    --
    -- ALERT_TECH Distribution
    --
    CURSOR C_EMAIL_RECIPIENTS IS
    SELECT EMAIL_RECIPIENTS.C_EMAIL_DEVELOPER
    FROM EMAIL_RECIPIENTS;


BEGIN


    IF LENGTH(P_MESSAGE) > 3500 THEN
        RAISE e_msg_exceeds_length;
    END IF;

   --
   -- GET ENVIRONMENT INFO
   --
   lv_env_name := GET_ENV_NAME;

   lv_env_location_msg := 'Environment:   '||lv_env_name||'<br>'||
                                             'Timestamp:   '||TO_CHAR(SYSDATE,'fmMonth ddTH')||' at '||TO_CHAR(SYSDATE,'hh:mi AM')||'<br>';

    --
    -- P_DISTRIBUTION = ALERT_TECH Group
    --
     IF P_DISTRIBUTION = 'ALERT_TECH' AND LV_ENV_NAME LIKE '%PROD%' THEN

            LV_ENV_LOCATION_MSG := LV_ENV_LOCATION_MSG||
                                                     'Distribution:   Group '||P_DISTRIBUTION||' specified.  Recipients are registered in EMAIL_RECIPIENTS.<br><br>';

            FOR R_EMAIL_RECIPIENTS IN C_EMAIL_RECIPIENTS LOOP
                 PK_EMAIL.SEND_EMAIL_MESSAGE (P_SENDER,
                                                                    R_EMAIL_RECIPIENTS.C_EMAIL_DEVELOPER,
                                                                    P_SUBJECT,
                                                                    lv_env_location_msg||
                                                                    P_MESSAGE||CHR(10)||CHR(10)
                                                                    );
            END LOOP;

     ELSE
            --
            -- P_DISTRIBUTION = DISTRIBUTION GROUP NOT PROVIDED. ROUTE BACK TO SENDER ONLY
            --
             LV_ENV_LOCATION_MSG := LV_ENV_LOCATION_MSG||
                                                       'Distribution:   Sender Only<br><br>';
             PK_EMAIL.SEND_EMAIL_MESSAGE (P_SENDER,
                                                                P_SENDER,
                                                                P_SUBJECT,
                                                                lv_env_location_msg||
                                                                P_MESSAGE||CHR(10)||CHR(10)
                                                                 );
     END IF;


EXCEPTION
    WHEN e_msg_exceeds_length THEN

       PK_TOOLS.SEND_KITT_LOG (101,
                                                 'PK_EMAIL',
                                                 'SEND_EMAIL_DISTRIBUTION',
                                                 'ERROR',
                                                 'Error processing email distribution.  Message exceeds 3500 characters',
                                                 SQLERRM,
                                                 NULL);

       RAISE_APPLICATION_ERROR (-20101, 'Error processing email distribution.  Message exceeds 3500 characters.');

    WHEN OTHERS THEN

      PK_TOOLS.SEND_KITT_LOG (101,
                                                 'PK_EMAIL',
                                                 'SEND_EMAIL_DISTRIBUTION',
                                                 'ERROR',
                                                 'Error processing email distribution.',
                                                 SQLERRM,
                                                 NULL);

       RAISE_APPLICATION_ERROR (-20102, 'Error processing email distribution.');

END;

END PK_EMAIL;
/
