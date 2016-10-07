DROP PROCEDURE TOOL_RESET_INDEX;

CREATE OR REPLACE PROCEDURE TOOL_RESET_INDEX IS

BEGIN
   
   for c in (select index_name from user_indexes where tablespace_name = 'KITTS_DATA' and index_type !='LOB') loop
   
     EXECUTE IMMEDIATE 'ALTER INDEX KITT_PROD.'||c.index_name||' REBUILD TABLESPACE KITTS_INDEX';
     
   end loop;
   
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_RESET_INDEX; 
/
