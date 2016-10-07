DROP PROCEDURE TOOL_COPY_LMC_MAX_HOURS;

CREATE OR REPLACE PROCEDURE           TOOL_COPY_LMC_MAX_HOURS IS

BEGIN
   
     for c in ( select p.N_CONTRACTOR_ID from CONTRACTOR p
               where p.C_CONTRACTOR_LABEL in ('DCR')) loop

     insert into CONTRACTOR_HOURS (N_CONTRACTOR_ID, C_PERIOD,N_ALLOWABLE_HOURS)
        select c.N_CONTRACTOR_ID, a.C_PERIOD, a.N_ALLOWABLE_HOURS
          from CONTRACTOR_HOURS a, CONTRACTOR b
        where a.N_CONTRACTOR_ID=b.N_CONTRACTOR_ID
          and b.C_CONTRACTOR_LABEL ='LMC' and a.C_PERIOD > 200812;
          
          commit;

   end loop;
   
   
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END ; 
/
