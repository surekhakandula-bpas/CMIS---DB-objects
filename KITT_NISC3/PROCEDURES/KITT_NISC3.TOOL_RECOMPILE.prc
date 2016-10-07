DROP PROCEDURE TOOL_RECOMPILE;

CREATE OR REPLACE PROCEDURE           TOOL_RECOMPILE IS

/******************************************************************************
   NAME:       TOOL_RECOMPILE
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        12/1/2009   Chao Yu       1. Created this procedure.

   NOTES:

   Recompile the views and stored procedures.
******************************************************************************/
BEGIN
   


   for c in (select object_name 
               from user_objects 
              where status = 'INVALID' 
                and object_type ='VIEW') loop
   
     EXECUTE IMMEDIATE 'ALTER VIEW '||c.object_name ||' COMPILE';

   end loop;
   
    for d in (select object_name 
                from user_objects 
               where status = 'INVALID' 
                 and object_type ='PROCEDURE') loop
   
     EXECUTE IMMEDIATE 'ALTER procedure '||d.object_name ||' COMPILE';

   end loop;

   
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_RECOMPILE; 
/
