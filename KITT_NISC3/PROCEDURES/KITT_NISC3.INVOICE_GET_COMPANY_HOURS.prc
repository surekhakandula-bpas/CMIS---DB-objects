DROP PROCEDURE INVOICE_GET_COMPANY_HOURS;

CREATE OR REPLACE PROCEDURE              "INVOICE_GET_COMPANY_HOURS" (
                                           MyCompanyID number,
                                           MyPeriod number,
                                           MyHours out number) AS 
BEGIN
  select N_ALLOWABLE_HOURS into MyHours
    from KITT_NISC3.HOURS_SCHEDULE
    where N_CONTRACTOR_ID = MyCompanyID
      and trim(C_PERIOD)=trim(to_char(MyPeriod));
EXCEPTION
     WHEN NO_DATA_FOUND THEN
       MyHours:=0;

     WHEN OTHERS THEN
       MyHours:=0;
        Raise;
END INVOICE_GET_COMPANY_HOURS;
/
