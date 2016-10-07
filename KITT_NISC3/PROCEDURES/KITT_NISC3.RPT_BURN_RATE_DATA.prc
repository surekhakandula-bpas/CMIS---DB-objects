DROP PROCEDURE RPT_BURN_RATE_DATA;

CREATE OR REPLACE PROCEDURE           RPT_BURN_RATE_DATA IS

/******************************************************************************
   NAME:       RPT_BURN_RATE_DATA 
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        3/30/2009   Chao Yu       1. Created this procedure.

   NOTES:

   ##### Need Un-Comment Approved condition when go to production
******************************************************************************/

MyYear varchar2(4);
MyMonth varchar2(2);

BEGIN
   

     
     update RPT_BRIDGE_BURN_RATE
        set N_INV_HOURS = 0,
            N_APP_HOURS = 0,
            F_INV_ACTIVE_MON = 'N',
            F_APP_ACTIVE_MON ='N',
            D_UPDATE_DATE = sysdate;
            
     commit;
       
    update RPT_BRIDGE_BURN_RATE_BY_YEAR
       set N_INV_HOURS_2008 = null,
           N_INV_HOURS_2009 = null,
           N_INV_HOURS_2010 = null,
           N_APP_HOURS_2008 = null,
           N_APP_HOURS_2009 = null,
           N_APP_HOURS_2010 = null,
           D_UPDATE_DATE = sysdate;
           
     commit;
           

      -- Invoice All      
     for p in ( 
                select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as INV_HOURS_ALL
                   from INVOICE_ITEM a,  INVOICE c
                  where a.N_INVOICE_ID = c.N_INVOICE_ID
                    --  and c.N_STATUS_NUMBER in (308, 309, 310)                  
                   and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
              group by a.N_INVOICE_PERIOD_YEAR_MONTH
              order by a.N_INVOICE_PERIOD_YEAR_MONTH ) loop
              
                          
               update RPT_BRIDGE_BURN_RATE
                  set N_INV_HOURS = NVL(p.INV_HOURS_ALL,0),
                      F_INV_ACTIVE_MON = 'Y'
                where N_PERIOD = p.YEAR_MONTH;

               commit;
               
               MyYear:= substr(to_char(p.YEAR_MONTH), 1,4);
               MyMonth :=substr(to_char(p.YEAR_MONTH), 5,2);
               
               if MyYear = '2008' then
               
                      update RPT_BRIDGE_BURN_RATE_BY_YEAR
                         set N_INV_HOURS_2008 = NVL(p.INV_HOURS_ALL,0)
                       where C_PERIOD =MyMonth;
                       
               elsif MyYear = '2009' then
               
                      update RPT_BRIDGE_BURN_RATE_BY_YEAR
                         set N_INV_HOURS_2009 = NVL(p.INV_HOURS_ALL,0)
                       where C_PERIOD =MyMonth;
                       
               else
               
                      update RPT_BRIDGE_BURN_RATE_BY_YEAR
                         set N_INV_HOURS_2010 = NVL(p.INV_HOURS_ALL,0)
                       where C_PERIOD =MyMonth;
 
               end if;
               
               commit;
              
     end loop;
     

 
    -- Approval 
    for n in (
             select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as APP_HOURS_ALL
                  from INVOICE_ITEM a,  INVOICE c
                  where a.N_INVOICE_ID = c.N_INVOICE_ID
                    and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
                    and (a.F_PMO_DISPUTE_FLAG is null or a.F_PMO_DISPUTE_FLAG ='N')
                --   and c.N_STATUS_NUMBER in (308, 309, 310)   
               group by a.N_INVOICE_PERIOD_YEAR_MONTH
               order by a.N_INVOICE_PERIOD_YEAR_MONTH ) loop
               
                         
               update RPT_BRIDGE_BURN_RATE
                  set N_APP_HOURS = NVL(n.APP_HOURS_ALL,0),
                      F_APP_ACTIVE_MON ='Y'
                where N_PERIOD = n.YEAR_MONTH;

               commit;   
               
               MyYear:= substr(to_char(n.YEAR_MONTH), 1,4);
               MyMonth :=substr(to_char(n.YEAR_MONTH), 5,2);
               
               if MyYear = '2008' then
               
                      update RPT_BRIDGE_BURN_RATE_BY_YEAR
                         set N_APP_HOURS_2008 = NVL(n.APP_HOURS_ALL,0)
                       where C_PERIOD =MyMonth;
                       
               elsif MyYear = '2009' then
               
                      update RPT_BRIDGE_BURN_RATE_BY_YEAR
                         set N_APP_HOURS_2009 = NVL(n.APP_HOURS_ALL,0)
                       where C_PERIOD =MyMonth;
                       
               else
               
                      update RPT_BRIDGE_BURN_RATE_BY_YEAR
                         set N_APP_HOURS_2010 = NVL(n.APP_HOURS_ALL,0)
                       where C_PERIOD =MyMonth;
 
               end if;
               
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
