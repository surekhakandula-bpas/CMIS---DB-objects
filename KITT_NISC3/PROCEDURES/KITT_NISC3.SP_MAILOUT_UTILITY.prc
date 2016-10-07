DROP PROCEDURE SP_MAILOUT_UTILITY;

CREATE OR REPLACE PROCEDURE            sp_mailout_utility(p_process_id IN Number default 0,
                                               sender       IN VARCHAR2,
                                               recipient    IN VARCHAR2,
                                               ccrecipient  IN VARCHAR2,
                                               subject      IN VARCHAR2,
                                               message      IN VARCHAR2) IS


/************************************************************************************************************
 Program Name:    sp_mailout_utility
 Author:          J Feld
 Create Date:    10/05/2015
 Purpose:         This procedure with invoke smtp mail
 
 Modified:
************************************************************************************************************/

  crlf               VARCHAR2(2) := UTL_TCP.CRLF;
  connection utl_smtp.connection;
  mailhost           VARCHAR2(30) := 'relay.faa.gov';  
  header             VARCHAR2(1000);
  email_body         varchar2(4000);
  v_index            number := 1;
  v_location         number := 0;
  v_disclaim         varchar2(4000) := null;
  v_message          varchar2(4000);
  v_PStatus          VARCHAR2(100);
  v_JOB_NUM          NUMBER;
  v_APP_NM           VARCHAR2(100) := 'KITT';
  v_PROCEDURE_NM     VARCHAR2(100) := 'SP_MAILOUT_UTILITY';
  v_INPUT_PARMS      VARCHAR2(4000);
  v_STEP             VARCHAR2(100);  
  
BEGIN

  v_JOB_NUM := JOB_DETAIL_SEQ.NEXTVAL;
  v_INPUT_PARMS := 'PID: '||p_process_id||' SENDER: '||sender||' RECIP: '||recipient||' CC: '||ccrecipient||' SUBJ: '||subject||' MSG: '||message;
  v_STEP := 'START';
  -- Input parms -  job_id, application_name, procedure_name, input_parms, step_descr, counter, comments, user_name
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,v_INPUT_PARMS,v_STEP,NULL,NULL,NULL);

  --
  -- Start the connection.
  --

/*    sp_jobdetail_41(p_process_id,
                  'IN send email',
                  'check parameter',
                  null,
                  'START',
                  subject ||'msg:'||message,
                  'MAILOUT');
*/

  v_STEP := 'CONNECTION';
  
  connection := utl_smtp.open_connection(mailhost, 25);


  header := 'Date: ' || TO_CHAR(SYSDATE, 'dd Mon yy hh24:mi:ss') || crlf ||
            'From: ' || sender || '' || crlf || 'Subject: ' || subject || crlf ||
            'To: ' || recipient || crlf || 'CC: ' || ccrecipient;

  --
  -- Handshake with the SMTP server
  --

  v_STEP := 'HANDSHAKE WITH SMTP SERVER';
  
  utl_smtp.helo(connection, mailhost);
  utl_smtp.mail(connection, sender);


  --
  -- Handle multiple recipients.  List must be parsed and sent using separate
  -- calls to UTL_SMTP.RCPT
  
  v_STEP := 'MULTIPLE RECIPIENTS';
  
  WHILE v_index < LENGTH(recipient) LOOP
      v_location := INSTR(recipient,',',v_index,1);

      IF v_location <> 0 THEN
          UTL_SMTP.RCPT(connection, TRIM(SUBSTR(recipient,v_index,v_location-v_index)));
          v_index := v_location + 1;
      ELSE
          UTL_SMTP.RCPT(connection, TRIM(SUBSTR(recipient,v_index,LENGTH(recipient))));
          v_index := LENGTH(recipient);
      END IF;
  END LOOP;

  -- Handle multiple ccrecipients.  
  
  v_STEP := 'MULTIPLE CC';
  
  v_index := 1;

  WHILE trim(ccrecipient) is not null and v_index < LENGTH(ccrecipient) LOOP
      v_location := INSTR(ccrecipient,',',v_index,1);

      IF v_location <> 0 THEN
          UTL_SMTP.RCPT(connection, TRIM(SUBSTR(ccrecipient,v_index,v_location-v_index)));
          v_index := v_location + 1;
      ELSE
          UTL_SMTP.RCPT(connection, TRIM(SUBSTR(ccrecipient,v_index,LENGTH(ccrecipient))));
          v_index := LENGTH(ccrecipient);
      END IF;
  END LOOP;

--  utl_smtp.rcpt(connection, recipient);

  v_STEP := 'UTL.SMTP.RCPT';
  
  if trim(ccrecipient) is not null then
     utl_smtp.rcpt(connection, ccrecipient); 
  end if;


  utl_smtp.open_data(connection);

  --
  -- Write the header
  --

  v_STEP := 'WRITE HEADER';
  
  utl_smtp.write_data(connection, header);

  v_STEP := 'WRITE MESSAGE';
  --
  -- The crlf is required to distinguish that what comes next is not simply part of the header.
  v_message := utl_tcp.CRLF||utl_tcp.CRLF||message; 

  utl_smtp.write_data(connection, v_message);

/*
  v_disclaim := chr(10)||chr(10)||chr(10)||'WARNING: This message may contain For Official Use 

Only (FOUO) or Sensitive Security Information (SSI) that is ';
  v_disclaim := v_disclaim ||'controlled under 49 CFR parts 15 and 1520. No part of this 

record may be disclosed to persons without ';
  v_disclaim := v_disclaim ||'a "need to know", as defined in 49 CFR parts 15 and 1520, except 

with the written permission of the ';
  v_disclaim := v_disclaim ||'Administrator of the Transportation Security Administration or 

the Secretary of Transportation. Unauthorized ';
  v_disclaim := v_disclaim ||'release may result in civil penalty or other action. For U.S. 

government agencies, public disclosure is governed ';
  v_disclaim := v_disclaim ||'by 5 U.S.C. 552 and 49 CFR parts 15 and 1520. If you received 

this message in error, please delete the message ';
  v_disclaim := v_disclaim ||'and contact the Help Desk, (405) 954-3000, identify the 

application.';
  email_body := v_disclaim || chr(10);
*/


/*  sp_jobdetail_41(p_process_id,
                  'Send Mail',
                  'Sending mail',
                  null,
                  'START: ',
                  'Recipient: ' || recipient || 'Message: ' || message,
                  'MAILOUT');
*/

--  utl_smtp.write_data(connection, v_disclaim);

  utl_smtp.close_data(connection);
  utl_smtp.quit(connection);

  COMMIT;
  --MIME-Version: 1.0

  v_STEP := 'COMPLETE';
  
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,NULL,NULL);
  
EXCEPTION
  WHEN UTL_SMTP.INVALID_OPERATION THEN
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,'Invalid Operation in SMTP transaction.',NULL);
--    sp_jobdetail_41(p_process_id,v_job_desc,v_step_desc,  null,'ERROR','Invalid Operation in SMTP transaction.',v_procedure);

  WHEN UTL_SMTP.TRANSIENT_ERROR THEN
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,'Temporary problems with sending email - try again later.',NULL);

  WHEN UTL_SMTP.PERMANENT_ERROR THEN
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,'Errors in code for SMTP transaction.',NULL);

  WHEN OTHERS THEN
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,'User Defined Error '||SQLERRM,NULL);

END sp_mailout_utility;
/

GRANT EXECUTE ON SP_MAILOUT_UTILITY TO KITT_KFDBUSER;
