DROP PROCEDURE SEND_EMAIL;

CREATE OR REPLACE PROCEDURE          send_email (
                                       sender     IN VARCHAR2,
                                       receiver   IN   VARCHAR2,
                                       subject    IN   VARCHAR2,
                                       MESSAGE    IN   VARCHAR2 )
IS

conn   UTL_SMTP.connection;
crlf   VARCHAR2 (2)        := CHR (13) || CHR (10);
mesg   VARCHAR2 (32000);

BEGIN
   -- Open connection 
   -- conn := UTL_SMTP.open_connection ('relay.faa.gov', 25);
   
   conn := UTL_SMTP.open_connection ('204.108.10.6', 25);
   
   -- Hand Shake 
   ---UTL_SMTP.helo (conn, 'relay.faa.gov');
  
   UTL_SMTP.helo (conn, '204.108.10.6');
   
   -- Configure sender and recipient to UTL_SMTP 
   
   UTL_SMTP.mail (conn, sender);
   UTL_SMTP.rcpt (conn, receiver);
   
   mesg :=
         'Date: '
      || TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss')
      || crlf
      || 'From:  KFDB AutoGenerator'
      || crlf
      || 'Subject: '
      || subject
      || crlf
      || 'To: '
      || receiver
      || crlf
      || 'THIS MESSAGE IS FOR NOTIFICATION PURPOSES ONLY.  PLEASE DO NOT REPLY TO THIS MESSAGE'
      || crlf
      || crlf
       || crlf
      || '*******************************************************************NOTICE**********************************************************************'
      || crlf
      || crlf
      || crlf
      || 'Attention Financial Analyst,'
      || crlf
      ||'The KITT Financial Database (KFDB) interfaces have updated KITT with Delphi data as of '||sysdate||' and the following records are brought to your attention:'
      --||'The KITT Financial Database (KFDB) interfaces have updated KITT with Delphi data as of xx/xx/xxxx and the following records are brought to your attention:'
      || crlf
      || crlf
      || crlf
      || MESSAGE
      || crlf
      || crlf
      || crlf
      || 'KFDB Disclaimer:'
      || crlf
      ||'You are provided with access to Financial Reports in order to perform the official FAA business, in conjunction with the employeess FAA job duties, and is not to be used for personal gain, personal business. Access to and proper use of KFDB financial data will be consistent with FAA mission, policy and procedures.';      

  --- Configure sending message 
   UTL_SMTP.DATA (conn, mesg);

  --- closing connection 
   UTL_SMTP.quit (conn);
   
  
END; 
/
