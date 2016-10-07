DROP PROCEDURE SUBMITJOB_INVOICE_LOAD;

CREATE OR REPLACE procedure           SUBMITJOB_INVOICE_LOAD
IS

begin

    DBMS_Job.isubmit(200,'INVOICE_LOAD_DATA_FROM_MIS;',trunc(sysdate+1)+5/24, 'trunc(SYSDATE+ 24/24,''HH'')');
    commit;
end; 
/
