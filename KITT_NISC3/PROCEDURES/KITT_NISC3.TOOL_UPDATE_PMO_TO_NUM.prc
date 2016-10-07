DROP PROCEDURE TOOL_UPDATE_PMO_TO_NUM;

CREATE OR REPLACE PROCEDURE TOOL_UPDATE_PMO_TO_NUM IS

BEGIN
   
    for p in (select distinct SUBSTR (KITT_TO_NUMBER,1,LENGTH (KITT_TO_NUMBER) - 3) AS KITT_BASE_ID, 
                     MIS_TO_NUMBER 
                     from V_MIS_TASK_ORDER_MAPPING ) loop
                     
               
               update TASK_ORDER a
                 SET a.C_PMO_MIS_TO_NUM = p.MIS_TO_NUMBER
               where SUBSTR (a.C_TASK_ORDER_NUMBER,1,LENGTH (a.C_TASK_ORDER_NUMBER) - 3) = p.KITT_BASE_ID;

    
       
          
    end loop;

    commit;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       rollback;
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_UPDATE_PMO_TO_NUM; 
/
