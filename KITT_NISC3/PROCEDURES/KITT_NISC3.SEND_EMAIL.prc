DROP PROCEDURE SEND_EMAIL;

CREATE OR REPLACE PROCEDURE            send_email (
                                       sender     IN VARCHAR2,
                                       receiver   IN   VARCHAR2,
                                       subject    IN   VARCHAR2,
                                       MESSAGE    IN   VARCHAR2,
                                       rec_role   IN   VARCHAR2:='KITTS technical support' )
IS

conn   UTL_SMTP.connection;
crlf   VARCHAR2 (2)        := CHR (13) || CHR (10);
mesg   VARCHAR2 (4000);

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

   if (rec_role ='CTR BUSINESS OPS' or rec_role ='PMO') then

    mesg := 'Content-Type: text/html; charset="US-ASCII" '
      || 'Date: '
      || TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss')
      || crlf
      || 'From: KITT System'
      || crlf
      || 'Subject: '
      || subject
      || crlf
      || 'To: '
      || receiver
      || crlf
      ||crlf
      || MESSAGE
      || crlf
      || crlf;


   else

   mesg :=
         'Date: '
      || TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss')
      || crlf
      || 'From: KITT System'
      || crlf
      || 'Subject: '
      || subject
      || crlf
      || 'To: '
      || receiver
      || crlf
      || '===================================================='
      || crlf
      || 'This message was sent by KITT automatic mailer.'
      || crlf
      || '===================================================='
      || crlf
      || crlf
      || MESSAGE
      || crlf
      || crlf
      || crlf
      || crlf
      || '========================================================'
      || crlf
      || 'If you are not a '||rec_role||', and received this email in error,'
      || crlf
      || 'please contact KITT Project Lead Tawfiq CTR Diab/AWA/CNTR/FAA. Thanks!';
      end if;
  --- Configure sending message
   UTL_SMTP.DATA (conn, mesg);

  --- closing connection
   UTL_SMTP.quit (conn);


END;
/
