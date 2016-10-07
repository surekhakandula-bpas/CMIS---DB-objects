DROP PROCEDURE RPT_FTE_INVOICE_ANALYSIS;

CREATE OR REPLACE PROCEDURE           RPT_FTE_INVOICE_ANALYSIS IS

/******************************************************************************
   NAME:       RPT_FTE_INVOICE_ANALYSIS 
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        3/24/2009   Chao Yu       1. Created this procedure.

   NOTES:

   ##### Need Un-Comment Approved condition when go to production
******************************************************************************/

MyAvgHours number;
MySumHours number;
MyLastMonth number;
MyInvTotalHours number;
MyInvTotalAll number;
MyAppTotalHours number;
MyAppTotalAll number;

BEGIN
   
     MyInvTotalHours:=0;
     MyInvTotalAll:=0;
     MyAppTotalHours:=0;
     MyAppTotalAll:=0;
     
     
     update RPT_FTE_ANALYSIS
        set N_INV_PERIOD_HOURS = 0,
            N_INV_PERIOD_ALL = 0,
            N_INV_TOTAL_HOURS = 0,
            N_INV_TOTAL_ALL = 0,
            N_APP_PERIOD_HOURS =0,
            N_APP_PERIOD_ALL  = 0,
            N_APP_TOTAL_HOURS = 0,
            N_APP_TOTAL_ALL   = 0,
            F_INV_PROJECTION  = 'Y',
            F_APP_PROJECTION  = 'Y',
            D_UPDATE_DATE = sysdate;
            
     commit;
       
     --  Invoice Hour Only  
     for c in (
                 select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as INV_HOURS_ONLY
                   from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                  where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                    and a.N_INVOICE_ID = c.N_INVOICE_ID
                    --  and c.N_STATUS_NUMBER in (308, 309, 310) 
                    and b.C_COST_TYPE_LABEL = 'Hours'
                    and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
               group by a.N_INVOICE_PERIOD_YEAR_MONTH
               order by a.N_INVOICE_PERIOD_YEAR_MONTH ) loop
               
               MyInvTotalHours:=MyInvTotalHours + NVL(c.INV_HOURS_ONLY,0);
               
               update RPT_FTE_ANALYSIS
                  set N_INV_PERIOD_HOURS = NVL(c.INV_HOURS_ONLY,0),
                      F_INV_PROJECTION ='N'  
                where N_INCURRED_PERIOD = c.YEAR_MONTH;

               commit;
             
     end loop;
     
         update RPT_FTE_ANALYSIS
            set N_INV_TOTAL_HOURS = MyInvTotalHours,
                D_UPDATE_DATE = sysdate
          where N_INCURRED_PERIOD = 300000;

          commit;  
               
          select Max(NVL(YEAR_MONTH,0)), AVG(NVL(INV_HOURS_ONLY,0)), SUM(NVL(INV_HOURS_ONLY,0)) into MyLastMonth,MyAvgHours, MySumHours 
            from (
                 select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as INV_HOURS_ONLY
                   from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                  where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                    and a.N_INVOICE_ID = c.N_INVOICE_ID
                    --  and c.N_STATUS_NUMBER in (308, 309, 310) 
                    and b.C_COST_TYPE_LABEL = 'Hours'
                    and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
               group by a.N_INVOICE_PERIOD_YEAR_MONTH );
 
          update RPT_FTE_ANALYSIS
             set N_INV_PERIOD_HOURS = NVL(MyAvgHours,0),
                 F_INV_PROJECTION ='Y'
          where N_INCURRED_PERIOD > MyLastMonth
            and N_INCURRED_PERIOD < 300000;
            
          update RPT_FTE_ANALYSIS
             set N_INV_PERIOD_HOURS = NVL(MySumHours ,0),
                 F_INV_PROJECTION ='N'
          where N_INCURRED_PERIOD =300000;
          
 
          commit;
 
          update RPT_FTE_ANALYSIS
             set N_INV_PERIOD_HOURS = ( select sum( NVL(N_INV_PERIOD_HOURS,0)) 
                                          from RPT_FTE_ANALYSIS
                                         where N_INCURRED_PERIOD < 300000),
                 F_INV_PROJECTION ='Y'
          where N_INCURRED_PERIOD =400000;
          
          commit;
          
     
      -- Invoice All exc ZCH      
     for p in ( 
                select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as INV_HOURS_ALL
                  from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                 where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                   and a.N_INVOICE_ID = c.N_INVOICE_ID
                    --  and c.N_STATUS_NUMBER in (308, 309, 310) 
                   and b.C_COST_TYPE_LABEL != 'ZCH'
                   and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
              group by a.N_INVOICE_PERIOD_YEAR_MONTH
              order by a.N_INVOICE_PERIOD_YEAR_MONTH ) loop
              
               MyInvTotalAll:=MyInvTotalAll + NVL(p.INV_HOURS_ALL,0);
                          
               update RPT_FTE_ANALYSIS
                  set N_INV_PERIOD_ALL = NVL(p.INV_HOURS_ALL,0)
                where N_INCURRED_PERIOD = p.YEAR_MONTH;

               commit;   
              
     end loop;
     
         update RPT_FTE_ANALYSIS
            set N_INV_TOTAL_ALL = MyInvTotalAll
          where N_INCURRED_PERIOD = 300000;

          commit;  
          
     
          select Max(NVL(YEAR_MONTH,0)), AVG(NVL(INV_HOURS_ALL,0)), SUM(NVL(INV_HOURS_ALL,0)) into MyLastMonth,MyAvgHours, MySumHours  
            from (
                select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as INV_HOURS_ALL
                 from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                 where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                   and a.N_INVOICE_ID = c.N_INVOICE_ID
                    --  and c.N_STATUS_NUMBER in (308, 309, 310) 
                   and b.C_COST_TYPE_LABEL != 'ZCH'
                   and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
              group by a.N_INVOICE_PERIOD_YEAR_MONTH);
     
           update RPT_FTE_ANALYSIS
              set N_INV_PERIOD_ALL = NVL(MyAvgHours,0)
            where N_INCURRED_PERIOD > MyLastMonth
              and N_INCURRED_PERIOD < 300000;
            
          update RPT_FTE_ANALYSIS
             set N_INV_PERIOD_ALL = NVL(MySumHours ,0)
          where N_INCURRED_PERIOD =300000;

          commit;
 
          update RPT_FTE_ANALYSIS
             set N_INV_PERIOD_ALL = ( select sum( N_INV_PERIOD_ALL) 
                                        from RPT_FTE_ANALYSIS
                                       where N_INCURRED_PERIOD < 300000)
          where N_INCURRED_PERIOD =400000;
          
          commit;          
       
    -- Approval Hour Only
    
    for m in (
             select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as APP_HOURS_ONLY
                   from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                  where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                    and a.N_INVOICE_ID = c.N_INVOICE_ID
                    and b.C_COST_TYPE_LABEL = 'Hours'
                    and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
                    and (a.F_PMO_DISPUTE_FLAG is null or a.F_PMO_DISPUTE_FLAG ='N')
                  --  and c.N_STATUS_NUMBER in (308, 309, 310) 
               group by a.N_INVOICE_PERIOD_YEAR_MONTH
               order by a.N_INVOICE_PERIOD_YEAR_MONTH ) loop
               
               MyAppTotalHours:=MyAppTotalHours + NVL(m.APP_HOURS_ONLY,0); 
                                    
               update RPT_FTE_ANALYSIS
                  set N_APP_PERIOD_HOURS = NVL(m.APP_HOURS_ONLY,0),
                      F_APP_PROJECTION ='N'
                where N_INCURRED_PERIOD = m.YEAR_MONTH;

               commit;       
               
    end loop;
    
                   
         update RPT_FTE_ANALYSIS
            set N_APP_TOTAL_HOURS = MyAppTotalHours
          where N_INCURRED_PERIOD = 300000;

          commit;  
          
             select Max(NVL(YEAR_MONTH,0)), AVG(NVL(APP_HOURS_ONLY,0)), SUM(NVL(APP_HOURS_ONLY,0)) into MyLastMonth,MyAvgHours, MySumHours  
               from (
                 select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as APP_HOURS_ONLY
                   from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                  where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                    and a.N_INVOICE_ID = c.N_INVOICE_ID
                    and b.C_COST_TYPE_LABEL = 'Hours'
                    and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
                    and (a.F_PMO_DISPUTE_FLAG is null or a.F_PMO_DISPUTE_FLAG ='N')
                --   and c.N_STATUS_NUMBER in (308, 309, 310) 
               group by a.N_INVOICE_PERIOD_YEAR_MONTH );
               
           update RPT_FTE_ANALYSIS
              set N_APP_PERIOD_HOURS = NVL(MyAvgHours,0),
                  F_APP_PROJECTION ='Y'
            where N_INCURRED_PERIOD > MyLastMonth
              and N_INCURRED_PERIOD < 300000;
              
        
          update RPT_FTE_ANALYSIS
             set N_APP_PERIOD_HOURS = NVL(MySumHours ,0),
                 F_APP_PROJECTION ='N'
          where N_INCURRED_PERIOD =300000;

          commit;
 
          update RPT_FTE_ANALYSIS
             set N_APP_PERIOD_HOURS = ( select sum( N_APP_PERIOD_HOURS) 
                                        from RPT_FTE_ANALYSIS
                                       where N_INCURRED_PERIOD < 300000),
                 F_APP_PROJECTION ='Y'
          where N_INCURRED_PERIOD =400000;
          
          commit;          
    
    
    
    -- Approval Excp ZCH 
    for n in (
             select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as APP_HOURS_ALL
                  from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                  where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                    and a.N_INVOICE_ID = c.N_INVOICE_ID
                    and b.C_COST_TYPE_LABEL != 'ZCH'
                    and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
                    and (a.F_PMO_DISPUTE_FLAG is null or a.F_PMO_DISPUTE_FLAG ='N')
                --   and c.N_STATUS_NUMBER in (308, 309, 310) 
               group by a.N_INVOICE_PERIOD_YEAR_MONTH
               order by a.N_INVOICE_PERIOD_YEAR_MONTH ) loop
               
           
               MyAppTotalAll:=MyAppTotalAll + NVL(n.APP_HOURS_ALL,0);
               
               update RPT_FTE_ANALYSIS
                  set N_APP_PERIOD_ALL = NVL(n.APP_HOURS_ALL,0)                 
                where N_INCURRED_PERIOD = n.YEAR_MONTH;

               commit;        
               
    end loop;
    
         update RPT_FTE_ANALYSIS
            set N_APP_TOTAL_ALL = MyAppTotalAll
          where N_INCURRED_PERIOD = 300000;

          commit;  
              
             select Max(NVL(YEAR_MONTH,0)), AVG(NVL(APP_HOURS_ALL,0)), SUM(NVL(APP_HOURS_ALL,0)) into MyLastMonth,MyAvgHours, MySumHours 
               from (
                 select a.N_INVOICE_PERIOD_YEAR_MONTH as YEAR_MONTH, sum(a.N_QUANTITY) as APP_HOURS_ALL
                  from INVOICE_ITEM a, COST_TYPE b, INVOICE c
                  where a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                    and a.N_INVOICE_ID = c.N_INVOICE_ID
                    and b.C_COST_TYPE_LABEL != 'ZCH'
                    and a.N_INVOICE_PERIOD_YEAR_MONTH >= 200803
                    and (a.F_PMO_DISPUTE_FLAG is null or a.F_PMO_DISPUTE_FLAG ='N')
                --    and c.N_STATUS_NUMBER in (308, 309, 310) 
               group by a.N_INVOICE_PERIOD_YEAR_MONTH);
               
           update RPT_FTE_ANALYSIS
              set N_APP_PERIOD_ALL = NVL(MyAvgHours,0)
            where N_INCURRED_PERIOD > MyLastMonth
              and N_INCURRED_PERIOD < 300000;
            
          update RPT_FTE_ANALYSIS
             set N_APP_PERIOD_ALL = NVL(MySumHours ,0)
          where N_INCURRED_PERIOD =300000;

          commit;
 
          update RPT_FTE_ANALYSIS
             set N_APP_PERIOD_ALL = ( select sum( N_APP_PERIOD_ALL) 
                                        from RPT_FTE_ANALYSIS
                                       where N_INCURRED_PERIOD < 300000)
          where N_INCURRED_PERIOD =400000;
          
          commit;          
    
           
    -- Calculate total hours for invoice and approval 
           
     MyInvTotalHours:=0;
     MyInvTotalAll:=0;
     MyAppTotalHours:=0;
     MyAppTotalAll:=0;
      
    for s in ( select N_INCURRED_PERIOD, N_INV_PERIOD_HOURS, N_INV_PERIOD_ALL, N_APP_PERIOD_HOURS, N_APP_PERIOD_ALL
                 from  RPT_FTE_ANALYSIS
                 where N_INCURRED_PERIOD < 300000 ) loop
                 
           
        MyInvTotalHours:=MyInvTotalHours + s.N_INV_PERIOD_HOURS;
        MyInvTotalAll:= MyInvTotalAll + s.N_INV_PERIOD_ALL;
        MyAppTotalHours:=MyAppTotalHours + s.N_APP_PERIOD_HOURS;
        MyAppTotalAll:=MyAppTotalAll + s.N_APP_PERIOD_ALL;
          
        update RPT_FTE_ANALYSIS
           set N_INV_TOTAL_HOURS = MyInvTotalHours,
               N_INV_TOTAL_ALL = MyInvTotalAll,
               N_APP_TOTAL_HOURS = MyAppTotalHours,
               N_APP_TOTAL_ALL = MyAppTotalAll,
               D_UPDATE_DATE = sysdate
        where  N_INCURRED_PERIOD = s.N_INCURRED_PERIOD;
        commit;
                 
    end loop;
                    
      update RPT_FTE_ANALYSIS
           set N_INV_TOTAL_HOURS = MyInvTotalHours,
               N_INV_TOTAL_ALL = MyInvTotalAll,
               N_APP_TOTAL_HOURS = MyAppTotalHours,
               N_APP_TOTAL_ALL = MyAppTotalAll,
               D_UPDATE_DATE = sysdate
        where  N_INCURRED_PERIOD = 400000;
       
        commit;     
     
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END; 
/
