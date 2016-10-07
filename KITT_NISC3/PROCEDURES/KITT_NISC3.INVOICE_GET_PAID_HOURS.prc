DROP PROCEDURE INVOICE_GET_PAID_HOURS;

CREATE OR REPLACE PROCEDURE              "INVOICE_GET_PAID_HOURS" (
                                        MyCompanyID number,
                                        MyEmployeeID number,
                                        MyWorkPeriod number,
                                        MyInoiveID number,
                                        MyHours out number) AS 
BEGIN
 select sum(NVL(N_QUANTITY,0)) into MyHours
                from KITT_NISC3.INVOICE_ITEM a, KITT_NISC3.COST_TYPE b, KITT_NISC3.INVOICE c
               where a.N_INVOICE_ID=c.N_INVOICE_ID
                 and a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                 and b.C_COST_TYPE_LABEL='Hours'
                 and a.N_CONTRACTOR_ID =MyCompanyID
                 and a.N_EMPLOYEE_ID =MyEmployeeID
                 and a.N_INVOICE_PERIOD_YEAR_MONTH =MyWorkPeriod
                 and a.N_INVOICE_ID < MyInoiveID
                 and (a.F_PMO_DISPUTE_FLAG is null or a.F_PMO_DISPUTE_FLAG = 'N')
                 and c.N_STATUS_NUMBER <> -200;
EXCEPTION
     WHEN NO_DATA_FOUND THEN
       MyHours:=0;

     WHEN OTHERS THEN
       MyHours:=0;
        Raise;
END INVOICE_GET_PAID_HOURS;
/
