DROP PROCEDURE RPT_ESTIMATE_ACTUAL_DATA;

CREATE OR REPLACE PROCEDURE           RPT_ESTIMATE_ACTUAL_DATA IS

/******************************************************************************
   NAME:       RPT_ESTIMATE_ACTUAL_DATA 
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/01/2009    Chao Yu        1. Created this procedure.


******************************************************************************/


MyTONumber varchar2(10);
MyStartdate date;
MyEndDate Date;
MyHours number;
MyCost number;
MyMonthPop number;

ctn number;
MyHourEstimateTD number;
MyHourTTLActual number;
MyHourDiff number;
MyCostEstimateTD number;
MyCostTTLActual number;
MyCostDiff number;


BEGIN
   
      delete from RPT_ESTIMATE_ACTUAL;
      commit;
      
      for p in (
              select distinct substr(c.C_TASK_ORDER_NUMBER,1, length (c.C_TASK_ORDER_NUMBER) -3) as INI_TO_NUM
                from INVOICE_ITEM a,
                     SUB_TASK_ORDER b,
                     TASK_ORDER c,
                     INVOICE d
               where a.N_SUB_TASK_ORDER_ID = b.N_SUB_TASK_ORDER_ID
                 and b.N_TASK_ORDER_ID = c.N_TASK_ORDER_ID
                 and a.N_INVOICE_ID = d.N_INVOICE_ID
                 --  and d.N_STATUS_NUMBER in (308, 309 ,310) 
            order by INI_TO_NUM) loop
            
         begin
            
           select count(*) into ctn
             from TASK_ORDER
            where N_STATE_NUMBER = 103
             and  substr(C_TASK_ORDER_NUMBER,1, length (C_TASK_ORDER_NUMBER) -3) = p.INI_TO_NUM;
             
           if ctn = 1 then
           
                  select 
                         C_TASK_ORDER_NUMBER,
                         D_POP_START_DATE,
                         D_POP_END_DATE,
                         N_TOTAL_LABOR_HOURS,
                         N_TASK_ORDER_COST_VALUE                  
                     into 
                         MyTONumber,
                         MyStartdate,
                         MyEndDate,
                         MyHours,
                         MyCost
                    from TASK_ORDER 
                   where N_STATE_NUMBER = 103
                     and  substr(C_TASK_ORDER_NUMBER,1, length (C_TASK_ORDER_NUMBER) -3) = p.INI_TO_NUM;
           
           else
              
                     select 
                         C_TASK_ORDER_NUMBER,
                         D_POP_START_DATE,
                         D_POP_END_DATE,
                         N_TOTAL_LABOR_HOURS,
                         N_TASK_ORDER_COST_VALUE                  
                     into 
                         MyTONumber,
                         MyStartdate,
                         MyEndDate,
                         MyHours,
                         MyCost
                    from TASK_ORDER 
                   where C_TASK_ORDER_NUMBER =  ( select Max(C_TASK_ORDER_NUMBER)
                                                    from TASK_ORDER
                                                   where substr(C_TASK_ORDER_NUMBER,1, length (C_TASK_ORDER_NUMBER) -3) = p.INI_TO_NUM
                                                    and N_STATE_NUMBER in (103, 104, 106, 107));
               
           end if;
           
           
           MyMonthPop:= round((MyEndDate - MyStartdate)/30.41667,0);
           
           insert into RPT_ESTIMATE_ACTUAL
              ( 
               C_TASK_ORDER_NUMBER,
               N_MONTHS_POP,
               N_HOURS_ESTIMATE,
               N_COST_ESTIMATE)
           values
             ( 
               MyTONumber,
               MyMonthPop,
               NVL(MyHours,0),
               NVL(MyCost,0));
               
            commit;
           
         EXCEPTION
             WHEN NO_DATA_FOUND THEN
                  dbms_output.put_line(p.INI_TO_NUM||', ');
                  NULL;
             WHEN OTHERS THEN
                  NULL;
         end;
         
     end loop;
  

    for m in (
             select INI_TO_NUM, count(*) as MONTH_INV
               from (
                   select distinct 
                        substr(c.C_TASK_ORDER_NUMBER,1, length (c.C_TASK_ORDER_NUMBER) -3) as INI_TO_NUM,
                         a.N_INVOICE_PERIOD_YEAR_MONTH
                    from INVOICE_ITEM a,
                         SUB_TASK_ORDER b,
                         TASK_ORDER c,
                         INVOICE d
                   where a.N_SUB_TASK_ORDER_ID = b.N_SUB_TASK_ORDER_ID
                     and b.N_TASK_ORDER_ID = c.N_TASK_ORDER_ID
                     --  and d.N_STATUS_NUMBER in (308, 309 ,310) 
                     and a.N_INVOICE_ID = d.N_INVOICE_ID)
            group by INI_TO_NUM
            order by INI_TO_NUM ) loop
      
        
        
        update RPT_ESTIMATE_ACTUAL
           set N_MONTHS_INV = NVL(m.MONTH_INV,0)
         where substr(C_TASK_ORDER_NUMBER,1, length (C_TASK_ORDER_NUMBER) -3)=m.INI_TO_NUM;
        commit;
        
        
     end loop;
     
    for x in (
             select INI_TO_NUM, DISPUTE, sum(N_QUANTITY) as HOURS, sum(N_FAA_COST) as COSTS
             from (
              select substr(c.C_TASK_ORDER_NUMBER,1, length (c.C_TASK_ORDER_NUMBER) -3) as INI_TO_NUM,
                     a.N_QUANTITY,
                     a.N_FAA_COST,
                     NVL(a.F_PMO_DISPUTE_FLAG,'N') as DISPUTE
                from INVOICE_ITEM a,
                     SUB_TASK_ORDER b,
                     TASK_ORDER c,
                     INVOICE d
               where a.N_SUB_TASK_ORDER_ID = b.N_SUB_TASK_ORDER_ID
                 and b.N_TASK_ORDER_ID = c.N_TASK_ORDER_ID
                 --  and d.N_STATUS_NUMBER in (308, 309 ,310) 
                 and a.N_INVOICE_ID = d.N_INVOICE_ID
                  )
            group by INI_TO_NUM, DISPUTE
            order by INI_TO_NUM, DISPUTE ) loop
            
        
          if x.DISPUTE = 'N' then
          
                update RPT_ESTIMATE_ACTUAL
                   set N_HOURS_ACTUAL_APP = NVL(x.HOURS,0),
                       N_COST_ACTUAL_APP = NVL(x.COSTS,0),
                       N_HOURS_ACTUAL_NOTAPP = NVL(N_HOURS_ACTUAL_NOTAPP,0),
                       N_COST_ACTUAL_NOTAPP = NVL(N_COST_ACTUAL_NOTAPP,0)
                 where substr(C_TASK_ORDER_NUMBER,1, length (C_TASK_ORDER_NUMBER) -3)=x.INI_TO_NUM;
        
          else
                update RPT_ESTIMATE_ACTUAL
                   set N_HOURS_ACTUAL_APP = NVL(N_HOURS_ACTUAL_APP,0),
                       N_COST_ACTUAL_APP = NVL(N_COST_ACTUAL_APP,0),
                       N_HOURS_ACTUAL_NOTAPP = NVL(x.HOURS,0),
                       N_COST_ACTUAL_NOTAPP = NVL(x.COSTS,0)
                 where substr(C_TASK_ORDER_NUMBER,1, length (C_TASK_ORDER_NUMBER) -3)=x.INI_TO_NUM;
          
          end if;   
            
    end loop;
    
    commit;
    
    for k in ( select 
                      C_TASK_ORDER_NUMBER,
                      N_MONTHS_POP,
                      N_MONTHS_INV,
                      N_HOURS_ESTIMATE,                      
                      N_HOURS_ACTUAL_APP,
                      N_HOURS_ACTUAL_NOTAPP,                                           
                      N_COST_ESTIMATE,                     
                      N_COST_ACTUAL_APP,
                      N_COST_ACTUAL_NOTAPP
                 from RPT_ESTIMATE_ACTUAL
                order by C_TASK_ORDER_NUMBER ) loop
           
    
         MyHourEstimateTD:= (k.N_HOURS_ESTIMATE/k.N_MONTHS_POP) * k.N_MONTHS_INV;
         MyHourTTLActual:= k.N_HOURS_ACTUAL_APP + k.N_HOURS_ACTUAL_NOTAPP;
         MyHourDiff := MyHourTTLActual - MyHourEstimateTD;
         MyCostEstimateTD := (k.N_COST_ESTIMATE/k.N_MONTHS_POP) * k.N_MONTHS_INV;
         MyCostTTLActual := k.N_COST_ACTUAL_APP + k.N_COST_ACTUAL_NOTAPP;
         MyCostDiff := MyCostTTLActual - MyCostEstimateTD;
         
         update  RPT_ESTIMATE_ACTUAL
            set  N_HOURS_ESTIMATE_TD = MyHourEstimateTD,
                 N_HOURS_TOTAL_ACTUAL = MyHourTTLActual,
                 N_HOURS_DIFF_ACTUAL_ESTIMATE = MyHourDiff,
                 N_COST_ESTIMATE_TD = MyCostEstimateTD,
                 N_COST_TOTAL_ACTUAL = MyCostTTLActual,
                 N_COST_DIFF_ACTUAL_ESTIMATE = MyCostDiff,
                 D_UPDATE_DATE = sysdate
          where C_TASK_ORDER_NUMBER = k.C_TASK_ORDER_NUMBER;
           
           commit;
                 
                 
                
    end loop;
     
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END; 
/
