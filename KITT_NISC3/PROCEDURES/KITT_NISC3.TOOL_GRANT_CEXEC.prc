DROP PROCEDURE TOOL_GRANT_CEXEC;

CREATE OR REPLACE PROCEDURE                TOOL_GRANT_CEXEC IS

BEGIN
 
   
   for c in (select object_name 
               from user_objects 
               where object_type in ('TABLE','VIEW') 
               and status ='VALID') loop
   
     EXECUTE IMMEDIATE 'GRANT SELECT ON ' ||c.object_name|| ' TO KITT_CEXEC';

   end loop;
   
  
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_GRANT_CEXEC; 
/
