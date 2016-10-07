DROP PROCEDURE SUBMITJOB_REMOVE;

CREATE OR REPLACE PROCEDURE SUBMITJOB_REMOVE IS


BEGIN
  
   DBMS_Job.REMOVE(100);
   commit;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END SUBMITJOB_REMOVE; 
/
