DROP PACKAGE PK_INVOICE_LOADING;

CREATE OR REPLACE PACKAGE            PK_INVOICE_LOADING AS
/******************************************************************************
   NAME:       PK_INVOICE_LOADING
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        7/26/2010    Chao Yu         1. Created this package.
******************************************************************************/

PROCEDURE    INVOICE_LOG_MULTI_PARAM (
                                      MyContractID number,
                                      MyInvoiceNum varchar2,
                                      MyLoadSeq number,
                                      MyMISInvoceID number,
                                      MyProblemItem varchar2,
                                      MyInitialData varchar2,
                                      MyLoadedData varchar2,
                                      MyReason varchar2);

 PROCEDURE       INVOICE_REMOVE ( MyContractID number,
                                 MyInvoiceID  number,
                                 MyInvoicePeriod number,
                                 MyMsg out varchar2);

PROCEDURE     INVOICE_SEND_PMO_NTP_EMAIL (MyInvoiceID number);

 PROCEDURE  INVOICE_SEND_VOUCHER_EMAIL (
                                         MyKITTContractNum varchar2,
                                         MyInvoiceID     number);

PROCEDURE  INVOICE_SEND_SUPPORT_EMAIL (
                                         MyKITTInvoiceID number,
                                         MyMISInvoiceNum varchar2 ,
                                         MySupportType varchar2,
                                         MyMsg varchar2);

PROCEDURE    INVOICE_ITEM_AUDIT (
                                           MyContractID number,
                                           MyInvoiceNum varchar2) ;

 PROCEDURE   INVOICE_LOAD_DATA_FROM_MIS (
                                         MyContrctNum number:=101,
                                         LoadStatus out varchar2);

 PROCEDURE   INVOICE_LOAD_BATCH;

 PROCEDURE   INVOICE_LOAD_BATCH_15MIN;


END PK_INVOICE_LOADING;
/

DROP PACKAGE BODY PK_INVOICE_LOADING;

CREATE OR REPLACE PACKAGE BODY            PK_INVOICE_LOADING AS
/******************************************************************************
   NAME:       PK_INVOICE_LOADING
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        7/26/2010   Chao Yu          1. Created this package body.
   1.1        2/08/2011   Chao Yu          2, comment out skill level audit
   1.2        2/24/2011   Chao Yu          3, Commet out to get Experience ID and set  MyExperienceID to null
   1.3        3/16/2011   Chao Yu          4, Ticket NISCIII-505 NTP task order level over written
   1.4        5/18/2011   Chao Yu          5, Ticket NISCIII-602: Generate "ODC Type Missing" warning message for all ODC items without ODC Type.
******************************************************************************/

PROCEDURE     INVOICE_GET_COMPANY_HOURS (
                                           MyCompanyID number,
                                           MyPeriod number,
                                           MyHours out number)
IS

/******************************************************************************
   NAME:       INVOICE_GET_COMPANY_HOURS
   PURPOSE:    This procedure return the allowed working hours
               for specific company and work period.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/27/2010  Chao Yu        1. Created this function.


******************************************************************************/


BEGIN


    select N_ALLOWABLE_HOURS into MyHours
    from HOURS_SCHEDULE
    where N_CONTRACTOR_ID = MyCompanyID
      and trim(C_PERIOD)=trim(to_char(MyPeriod));



EXCEPTION
     WHEN NO_DATA_FOUND THEN
       MyHours:=0;

     WHEN OTHERS THEN
       MyHours:=0;
        Raise;

END;

PROCEDURE   INVOICE_GET_COMPANY_ID (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyCompany varchar2,
                                           MyCompanyID out number,
                                           MyStatus in out number)
IS

/******************************************************************************
   NAME:       INVOICE_GET_COMPANY_ID
   PURPOSE:    Validate Company information. If Company doesn't exist,
               then insert this company into table.
               return CompanyID and loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        07/30/2010  Chao Yu        1. Created this function.

******************************************************************************/


MyCompanyName varchar2(50);
ctn number:=0;
Msg varchar2(4000);

BEGIN

      if NVL(MyCompany,'N/A') = 'N/A' then  -- missing company data in invoice record.

         MyCompanyID:= null;

         return;

      end if;

      MyCompanyName:= trim(MyCompany);
      select count(*) into ctn from CONTRACTOR where trim(C_CONTRACTOR_LABEL) =MyCompanyName;

      if ctn = 0 then -- issing company data.

        MyCompanyID:= null;
        INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Company ID',
                                       null,
                                       'Failed',
                                       MyCompanyName ||' is not availabel in KITT system.');


         if MyStatus < 4 then
             MyStatus:=4;  -- Set to Failed status.
         end if;

      elsif ctn=1 then -- return company id.

        select N_CONTRACTOR_ID into MyCompanyID
          from CONTRACTOR
         where trim(C_CONTRACTOR_LABEL) =MyCompanyName;

      else  -- return the first company id.

          for c in (select N_CONTRACTOR_ID
                      from CONTRACTOR
                     where trim(C_CONTRACTOR_LABEL) =MyCompanyName
                     order by N_CONTRACTOR_ID ) loop

              MyCompanyID:=c.N_CONTRACTOR_ID;
              exit;

          end loop;

          INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Company ID',
                                       MyCompanyName,
                                       'Warning',
                                       'Duplicated records exist for '||MyCompanyName||'.');

          if MyStatus < 3 then
             MyStatus:=3;  -- Set to warning status.
         end if;

      end if;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
        null;
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Company ID',
                                        MyCompanyName,
                                        'Failed',
                                        Msg);

       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
       end if;

END;



PROCEDURE   INVOICE_GET_EMPLOYEE_ID (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyCompanyID varchar2,
                                           MyNISCNum number,
                                           MyLastName varchar2,
                                           MyFirstName varchar2,
                                           MyEmployeeID out number,
                                           MyStatus in out varchar2)
IS

/******************************************************************************
   NAME:       INVOICE_GET_EMPLOYEE_ID
   PURPOSE:    Validate employee information. If employee
               doesn't exist, then insert this employee into tables.
               return employeeID and loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        07/30/2010  Chao Yu        1. Created this function.


******************************************************************************/


MyCurrFirstName varchar2(25);
MyCurrLastName varchar2(35);
MyCurrCompanyID number;
ctn number:=0;
Msg varchar2(4000);

BEGIN

  if MyNISCNum = 0 then
    -- This invoice item is not associated with employee, so assigned employeeID to null, That means N/A.
    MyEmployeeID := null;

  else

      select count(*) into ctn from EMPLOYEE where N_NISC_ID =MyNISCNum;


      if ctn = 0 then
         -- This employee doesn't exist, add it to employee table.
         select SEQ_EMPLOYEE.nextval into MyEmployeeID from dual;
         insert into EMPLOYEE (
                      N_EMPLOYEE_ID,
                      N_CONTRACTOR_ID,
                      N_NISC_ID,
                      C_FIRST_NAME,
                      C_LAST_NAME)
              values( MyEmployeeID,
                      MyCompanyID,
                      MyNISCNum,
                      trim(MyFirstName),
                      trim(MyLastName));
         commit;

         INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Employee ID',
                                       null,
                                       MyEmployeeID,
                                       'Add a new employee '||trim(MyFirstName)||' '||trim(MyLastName)||'('||MyNISCNum||') with ID:'||MyEmployeeID||'.');

      elsif (ctn = 1) then

        -- This employee exists.
        select N_CONTRACTOR_ID,N_EMPLOYEE_ID,trim(C_FIRST_NAME),trim(C_LAST_NAME)
          into MyCurrCompanyID,MyEmployeeID, MyCurrFirstName, MyCurrLastName
          from EMPLOYEE
         where N_NISC_ID =MyNISCNum;

        -- This employee changed his company, update company information in Employee table.
         if MyCurrCompanyID !=MyCompanyID then

            update EMPLOYEE
               set N_CONTRACTOR_ID =MyCompanyID
             where N_NISC_ID =MyNISCNum;
             commit;

             INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Employee Company ID',
                                       MyCurrCompanyID,
                                       MyCompanyID,
                                       'Update the company ID from '||MyCurrCompanyID||' to '||MyCompanyID||' for the employee '||trim(MyFirstName)||' '||trim(MyLastName)||'('||MyNISCNum||').');

         end if;

         -- This employee changed his name. Update his name information in employee table.
         if trim(MyCurrFirstName) !=trim(MyFirstName) or trim(MyCurrLastName) != trim(MyLastName) then

            update EMPLOYEE
               set C_FIRST_NAME =trim(MyFirstName),
                   C_LAST_NAME=trim(MyLastName)
             where N_NISC_ID =MyNISCNum;
             commit;

             INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Employee Name',
                                       trim(MyCurrFirstName)||' '||trim(MyCurrLastName),
                                       trim(MyFirstName)||' '||trim(MyLastName),
                                       'Update the name of the employee ('||MyNISCNum||') from '||trim(MyCurrFirstName)||' '||trim(MyCurrLastName)||' to '||trim(MyFirstName)||' '||trim(MyLastName)||'.');


         end if;

      else
        -- Should be never happen.
        MyEmployeeID := null;
        INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Employee ID',
                                       'NISC NUM:'||MyNISCNum,
                                       'Failed',
                                       'Duplicated NISC NUM '||MyNISCNum||' in Employee table.');

        if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
        end if;
      end if;
   end if;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       dbms_output.put_line(to_char(SQLCODE) ||'-'||SQLERRM||'.');
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Employee ID',
                                       'NISC NUM:'||MyNISCNum,
                                       'Failed',
                                        Msg);

       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
       end if;

END;



PROCEDURE  INVOICE_GET_EXPERIENCE_ID (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyLevel varchar2,
                                           MyExperienceID out number,
                                           MyStatus in out number)
IS

/******************************************************************************
   NAME:       INVOICE_GET_EXPERIENCE_ID
   PURPOSE:    Validate Experience information.
               return ExperienceID and loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0       08/02/2010  Chao Yu        1. Created this function.


******************************************************************************/


MyExperienceLevel varchar2(50);
ctn number:=0;
Msg varchar2(4000);

BEGIN

    MyExperienceLevel:= trim(MyLevel);

    if MyExperienceLevel='N/A' then -- ODC type entry, not related to employee.

        MyExperienceID:=null;

    else

      select count(*) into ctn from EXPERIENCE where Upper(trim(C_EXPERIENCE_LABEL)) =Upper(MyExperienceLevel);

      if ctn = 0 then

         MyExperienceID:=null;
         INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Experience ID',
                                       Upper(MyExperienceLevel),
                                       'Warning',
                                       Upper(MyExperienceLevel)||' doesn''t exit in KITT.');


         if MyStatus < 3 then
           MyStatus:=3; -- Set to Warning status.
         end if;

      elsif ctn = 1 then

        select N_EXPERIENCE_ID into MyExperienceID
          from EXPERIENCE
         where Upper(trim(C_EXPERIENCE_LABEL)) =Upper(MyExperienceLevel);

      else
          for c in ( select N_EXPERIENCE_ID
                      from EXPERIENCE
                     where Upper(trim(C_EXPERIENCE_LABEL)) =Upper(MyExperienceLevel)
                     order by N_EXPERIENCE_ID) loop

            MyExperienceID:=c.N_EXPERIENCE_ID;
            exit;

         end loop;


         INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Experience ID',
                                       Upper(MyExperienceLevel),
                                       'Error',
                                       'Duplicated records exist for '||MyExperienceLevel||'.');

      end if;
    end if;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Experience ID',
                                       MyExperienceLevel,
                                       'Failed',
                                       Msg);

       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
       end if;

END;




PROCEDURE   INVOICE_GET_LOAD_SEQ_NUM
                                    (MyContractID in number,
                                     MyInvoiceNum in varchar2,
                                     MyLoadSeq out number)
IS

/******************************************************************************
   NAME:       INVOICE_GET_LOAD_SEQ_NUM
   PURPOSE:    Return the next loading sequence number.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0       07/27/2010  Chao Yu        1. Created this function.

******************************************************************************/

ctn number;


BEGIN

       select count(*) into ctn
         from INVOICE_LOAD_LOG
        where N_CONTRACT_ID = MyContractID
          and upper(trim(C_INVOICE_NUM)) = upper(trim(MyInvoiceNum));
       if ctn > 0 then

          select Max(N_LOAD_SEQ) + 1 into MyLoadSeq
            from INVOICE_LOAD_LOG
           where N_CONTRACT_ID = MyContractID
             and upper(trim(C_INVOICE_NUM)) = upper(trim(MyInvoiceNum));
       else
           MyLoadSeq:= 1;
       end if;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END;



PROCEDURE     INVOICE_GET_PAID_HOURS (
                                        MyCompanyID number,
                                        MyEmployeeID number,
                                        MyWorkPeriod number,
                                        MyInoiveID number,
                                        MyHours out number)
IS

/******************************************************************************
   NAME:       INVOICE_GET_PAID_HOURS
   PURPOSE:    This procedure return the paid working hours
               for specific company, employee and work period.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/27/2010    Chao Yu        1. Created this function.

   Note: The hours include paid hours and previous pending invoice
******************************************************************************/


BEGIN


              select sum(NVL(N_QUANTITY,0)) into MyHours
                from INVOICE_ITEM a, COST_TYPE b, INVOICE c
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

END;



PROCEDURE   INVOICE_GET_PENDING_HOURS (
                                           MyCompanyID number,
                                           MyEmployeeID number,
                                           MyWorkPeriod number,
                                           MyInoiveID number,
                                           MyHours out number)
IS

/******************************************************************************
   NAME:       INVOICE_GET_PENDING_HOURS
   PURPOSE:    This procedure return the current pending working hours
               for specific company, employee and work period.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/27/2010   Chao Yu        1. Created this function.

  Note: only return the hours of the current pending invoice,
        not including the hours of the previous pending invoice
******************************************************************************/

BEGIN

              select sum(NVL(N_QUANTITY,0)) into MyHours
                from INVOICE_ITEM a, COST_TYPE b, INVOICE c
               where a.N_INVOICE_ID=c.N_INVOICE_ID
                 and a.N_COST_TYPE_ID = b.N_COST_TYPE_ID
                 and b.C_COST_TYPE_LABEL='Hours'
                 and a.N_CONTRACTOR_ID =MyCompanyID
                 and a.N_EMPLOYEE_ID =MyEmployeeID
                 and a.N_INVOICE_PERIOD_YEAR_MONTH =MyWorkPeriod
                 and a.N_INVOICE_ID = MyInoiveID
                 and (a.F_PMO_DISPUTE_FLAG is null or a.F_PMO_DISPUTE_FLAG = 'N')
                 and c.N_STATUS_NUMBER <> -200;


EXCEPTION
     WHEN NO_DATA_FOUND THEN
       MyHours:=0;

     WHEN OTHERS THEN
       MyHours:=0;
        Raise;

END;



PROCEDURE     INVOICE_GET_SUBTO_DATES (    MySubTaskOrderID number,
                                           MyStartDate out date,
                                           MyEndDate out date)
IS

/******************************************************************************
   NAME:       INVOICE_GET_SUBTO_DATES
   PURPOSE:    This procedure return the sub task order start and end date.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0       07/27/2010 Chao Yu        1. Created this function.


******************************************************************************/


BEGIN


    select NVL(D_SUB_TASK_ORDER_START_DATE, to_date('01/01/1900','MM/DD/YYYY')),
           DECODE(
                  D_INACTIVE_DATE, null,
                  NVL(D_SUB_TASK_ORDER_END_DATE, to_date('01/02/1900','MM/DD/YYYY')),
                  LEAST(NVL(D_SUB_TASK_ORDER_END_DATE, to_date('01/02/1900','MM/DD/YYYY')), D_INACTIVE_DATE )
                 ) as EndDate
      into MyStartDate,MyEndDate
     from SUB_TASK_ORDER
    where N_SUB_TASK_ORDER_ID = MySubTaskOrderID;

EXCEPTION
     WHEN NO_DATA_FOUND THEN
       MyStartDate:=to_date('01/01/1900','MM/DD/YYYY');
       MyEndDate:=to_date('01/02/1900','MM/DD/YYYY');

     WHEN OTHERS THEN
       MyStartDate:=to_date('01/01/1900','MM/DD/YYYY');
       MyEndDate:=to_date('01/02/1900','MM/DD/YYYY');
        Raise;

END;



PROCEDURE    INVOICE_GET_SUBTO_FUND (
                                           MyTaskOrderBaseID number,
                                           MySubTaskOrderName varchar2,
                                           MyInvoiceID  number,
                                           MyAvailableFund out number)
IS

/******************************************************************************
   NAME:       INVOICE_GET_SUBTO_FUND
   PURPOSE:    This procedure return the available fund for specific sub task order.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        07/27/2010   Chao Yu        1. Created this function.


******************************************************************************/
PenddingInvoiceAmount number;
MyETOAvailableFund number;


BEGIN


    -- For first time loading audit including all paid and pending invoice


      select SUB_TASK_AVAILABLE_AMOUNT into  MyAvailableFund
       from V_KITTV_SUBTO_AVAILABLE_AMOUNT
      where N_TASK_ORDER_BASE_ID = MyTaskOrderBaseID
        and C_SUB_TASK_ORDER_NAME = MySubTaskOrderName;



    -- For both first time loading audit and re-audit after later invoice loaded into database
    -- Pending invoice will not include the invoices which are later than current audited invoice.
    /*
     select SUB_TASK_ETO_AVAIL_AMOUNT into  MyETOAvailableFund
       from V_KITTV_SUBTO_AVAILABLE_AMOUNT
      where N_TASK_ORDER_BASE_ID = MyTaskOrderBaseID
        and C_SUB_TASK_ORDER_NAME = MySubTaskOrderName;


      SELECT
            SUM(CASE WHEN NVL (b.n_faa_cost, 0) > 0 THEN NVL (b.n_faa_cost, 0) ELSE 0 END) AS sub_task_pending_invoice_woc
            into PenddingInvoiceAmount
       FROM invoice a, invoice_item b
      WHERE a.n_invoice_id = b.n_invoice_id
        AND a.n_status_number NOT IN (306, 307, 308, 309, 310, 311, -200)
        AND a.n_invoice_id <= MyInvoiceID
        AND b.N_TASK_ORDER_BASE_ID = MyTaskOrderBaseID
        AND b.C_SUB_TASK_ORDER_NAME = MySubTaskOrderName;


       MyAvailableFund:= (MyETOAvailableFund - PenddingInvoiceAmount);
     */

EXCEPTION
     WHEN NO_DATA_FOUND THEN

       MyAvailableFund:= 0;

     WHEN OTHERS THEN

       MyAvailableFund:= 0;
       Raise;

END;



PROCEDURE   INVOICE_ITEM_AUDIT_MSG (
                             MY_INVOICE_ID  number,
                             MY_INVOICE_ITEM_ID number,
                             MY_PROBLEM_ITEM varchar2,
                             MY_REASON varchar2,
                             MY_TYPE varchar2 )

IS

/******************************************************************************
   NAME:       INVOICE_ITEM_AUDIT_MSG
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0       07/28/2010  Chao Yu       1. Created this procedure.

   NOTES:

******************************************************************************/
BEGIN

     insert into INVOICE_ITEM_WARNING_MSG
                           (
                             N_INVOICE_ID,
                             N_INVOICE_ITEM_ID,
                             C_PROBLEM_ITEM,
                             C_REASON,
                             C_TYPE,
                             D_AUDIT_DATE
                           )
         values
                           (
                             MY_INVOICE_ID,
                             MY_INVOICE_ITEM_ID,
                             MY_PROBLEM_ITEM,
                             MY_REASON,
                             MY_TYPE,
                             sysdate
                           );
        commit;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END INVOICE_ITEM_AUDIT_MSG;

PROCEDURE     INVOICE_LOG_MSG_PARAM3 (
                                     MyContractID number,
                                     MyInvoiceNum varchar2,
                                     MyLoadSeq number,
                                     MyReason varchar2)
IS
/******************************************************************************
   NAME:       SET_INVOICE_LOG_MSG_PARAM3
   PURPOSE:   Insert a message into Invoice Log table.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/28/2010   Chao Yu        1. Created this procedure.

******************************************************************************/

MyLogID number:=0;
ctn number:=0;


BEGIN

      -- Get LogID from sequence
       select SEQ_INVOICE_LOAD_LOG.nextval into MyLogID from dual;


       INSERT INTO INVOICE_LOAD_LOG
                  (N_LOG_ID,
                   N_CONTRACT_ID,
                   C_INVOICE_NUM,
                   N_LOAD_SEQ,
                   N_MIS_INVOICE_ITEM_ID,
                   C_PROBLEM_ITEM,
                   C_INITIAL_DATA,
                   N_LOADED_DATA,
                   C_REASON,
                   D_CREATE_DATE)
            values (MyLogID,
                    MyContractID,
                    MyInvoiceNum,
                    MyLoadSeq,
                    null,
                    null,
                    null,
                    null,
                    MyReason,
                    sysdate);
            commit;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       RAISE;
END INVOICE_LOG_MSG_PARAM3;


PROCEDURE    INVOICE_LOG_MULTI_PARAM (
                                      MyContractID number,
                                      MyInvoiceNum varchar2,
                                      MyLoadSeq number,
                                      MyMISInvoceID number,
                                      MyProblemItem varchar2,
                                      MyInitialData varchar2,
                                      MyLoadedData varchar2,
                                      MyReason varchar2)
IS

/******************************************************************************
   NAME:       SET_INVOICE_LOG_MULTI_PARAM
   PURPOSE:   Insert a message into Invoice Log table. Multi-parameters were passed.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/28/2010  Chao Yu        1. Created this procedure.

******************************************************************************/

MyLogID number:=0;

BEGIN

       select SEQ_INVOICE_LOAD_LOG.nextval into MyLogID from dual;

       INSERT INTO INVOICE_LOAD_LOG
                  (N_LOG_ID,
                   N_CONTRACT_ID,
                   C_INVOICE_NUM,
                   N_LOAD_SEQ,
                   N_MIS_INVOICE_ITEM_ID,
                   C_PROBLEM_ITEM,
                   C_INITIAL_DATA,
                   N_LOADED_DATA,
                   C_REASON,
                   D_CREATE_DATE)
            values (MyLogID,
                    MyContractID,
                    MyInvoiceNum,
                    MyLoadSeq,
                    MyMISInvoceID,
                    MyProblemItem,
                    MyInitialData,
                    MyLoadedData,
                    MyReason,
                    sysdate);
            commit;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       RAISE;
END INVOICE_LOG_MULTI_PARAM;


PROCEDURE       INVOICE_REMOVE ( MyContractID number,
                                 MyInvoiceID  number,
                                 MyInvoicePeriod number,
                                 MyMsg out varchar2)

IS
/******************************************************************************

  Note:For special purpose:
        When an invoice has already loaded into invoice and invoice item tables. for some reason,
        really need to remove the rejected invoice data in invoice and invoice item table,
        Only the invoice whose status is rejected and no payment and letter created can be removed.

        There are three steps to process replacing:
         1) A/P rejecte this invoice.
         2) Aak MIS resubmit the invoice data with problems fixed for this invoice.
         3) Call procedure INVOICE_LOAD_DATA_FROM_MIS

        Also can just run this procedure to remove one rejected invoice.

******************************************************************************/

MyPaymentCtn number;
MyLetterCtn  number;
ctn number:=0;



begin

     MyMsg := null;

         select count(*) into ctn
           from INVOICE
          where N_INVOICE_ID = MyInvoiceID
            and N_CONTRACT_ID = MyContractID
            and N_INVOICE_YEAR_MONTH = MyInvoicePeriod
            and N_STATUS_NUMBER = -200 ;

          If ctn > 0 then

             select count(*) into MyPaymentCtn
               from PAYMENT_INSTRUCTION
              where N_INVOICE_ID =MyInvoiceID;

             select count(*) into MyLetterCtn
               from INVOICE_CERTIFICATION_LETTER
              where N_INVOICE_ID =MyInvoiceID;

            if (MyPaymentCtn + MyLetterCtn) = 0 then



              delete from Invoice_Service
               where n_voucher_id = (select n_voucher_id
                                       from invoice_voucher
                                      where n_invoice_ID =MyInvoiceID);

              delete from Invoice_Voucher where n_invoice_id =MyInvoiceID;


              delete from CONTRACT_DSA
               where N_OBJECT_ID =MyInvoiceID
                 and c_object_type in ('ICF', 'NPL', 'Invoice Voucher');


              delete from INVOICE_LOAD_LOG where C_INVOICE_NUM = ( select C_MIS_INVOICE_NUMBER
                                                                     from invoice
                                                                    where N_INVOICE_ID = MyInvoiceID);

              delete from INVOICE_LOAD_AUDIT where C_MIS_INVOICE_NUMBER = ( select C_MIS_INVOICE_NUMBER
                                                                              from invoice
                                                                             where N_INVOICE_ID = MyInvoiceID);


              update V_MIS_INVOICE_PULLING_STATUS
                 set N_STATE_ID = 6
               where N_INVOICE_NUM = ( select C_MIS_INVOICE_NUMBER
                                        from invoice
                                       where N_INVOICE_ID = MyInvoiceID)
                and N_STATE_ID <> 1 ;

              delete from INVOICE_ITEM_WARNING_MSG where N_INVOICE_ID = MyInvoiceID;
              delete from INVOICE_ITEM where N_INVOICE_ID = MyInvoiceID;
              delete from INVOICE  where N_INVOICE_ID = MyInvoiceID;


              commit;


              MyMsg := ' The Rejected invoice '||MyInvoiceID||' (Period:'||MyInvoicePeriod||') has been removed from database successfully.';

          else


              MyMsg := ' The Rejected invoice '||MyInvoiceID||' (Period:'||MyInvoicePeriod||') could not be removed after generated payment instruction.';



          end if;


      end if;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       MyMsg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
     WHEN OTHERS THEN

       MyMsg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       Rollback;
       RAISE;
END INVOICE_REMOVE;


PROCEDURE    INVOICE_SEND_LOAD_STATUS_EMAIL (
                                              MyKITTContractID number,
                                              MyMISInvoiceNum     varchar2,
                                              MyStatus         number,
                                              MyMSG            varchar2:=null)

IS
/******************************************************************************
   NAME:       INVOICE_SEND_LOAD_STATUS_EMAIL
   PURPOSE:   Send an email notification when the invoice is just uploaded into database

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/28/2010  Chao Yu        1. Created this procedure.

******************************************************************************/

   crlf               VARCHAR2 (2)    := CHR (13) || CHR (10);
   Sender             VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Receiver           VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Subject            VARCHAR2 (500)  := ' ';
   Message1           VARCHAR2 (400)  := ' ';
   Message2           VARCHAR2 (4000);
   LoadStatusDesc     varchar2(50);
   ctn                number;
   MyRole             varchar2(100);
   CurrDB             varchar2(20);
   ContractNum        varchar2(50);
   ContractName       varchar2(200);
   InvoiceTotal       number;
   InvoicePeriod      number;
   InvoiceID          number;
   InvoiceNumDesc     varchar2(50);


BEGIN


 if NVL(MyStatus,0) >0 then

     if MyStatus <> 7 then

        select lower(C_STATE_DESC) into LoadStatusDesc
          from V_MIS_INVOICE_PULLING_STATE
         where  N_STATE_ID = MyStatus;

         if  MyStatus < 4 then

            Subject:='The invoce data for the invoice number '||MyMISInvoiceNum||' have been loaded '||LoadStatusDesc;
             Message1 :=' '
             || crlf
             || crlf
             || 'Invoice data for the invoice number '||MyMISInvoiceNum||' have been loaded '||LoadStatusDesc||'!'
             || crlf
             || 'Following is the information from loading log file.'
             || crlf;
       else

           Subject:='The invoce data loading for the invoice number '||MyMISInvoiceNum||' was '||LoadStatusDesc;
           Message1 :=' '
            || crlf
            || crlf
            || 'The invoice data loading for the invoice number '||MyMISInvoiceNum||' was '||LoadStatusDesc||'!'
            || crlf
            || 'Following is the information from loading log file.'
            || crlf;

       end if;

    else

          Subject:='The invoce data for the invoice number '||MyMISInvoiceNum||' have been loaded successfully.  But Audit was failed.';
             Message1 :=' '
             || crlf
             || crlf
             || 'Invoice data for the invoice number '||MyMISInvoiceNum||' have been loaded successfully. But audit was failed.'
             || crlf
             || 'Following is the information from loading log file.'
             || crlf;

   end if;

   end if;

   if NVL(MyMSG,'N/A') !='N/A' then

        Subject:='The invoice number '||MyMISInvoiceNum||' have not been loaded yet';
        Message2 :=MyMSG;


   else

     ctn :=1;
     Message2:=Message1;
     for c  in (select C_REASON from INVOICE_LOAD_LOG
                 where N_CONTRACT_ID = MyKITTContractID
                   and C_INVOICE_NUM =MyMISInvoiceNum
                   and N_LOAD_SEQ = ( select max(distinct N_LOAD_SEQ)
                                      from INVOICE_LOAD_LOG
                                     where N_CONTRACT_ID = MyKITTContractID
                                       and C_INVOICE_NUM =MyMISInvoiceNum)
            order by N_LOG_ID) loop


          Message2:=Message2 || ctn ||'. '||c.C_REASON ||crlf;
          ctn:=ctn+1;

          If length(Message2) > 1500 then

             Message2 := Message2 ||' ... More...';
             exit;

          end if;

      end loop;



   end if;



   CurrDB := GET_ENV_NAME ;

    If CurrDB = 'NISC3_PROD' then

        Receiver:='sara.h.pausley@lmco.com';
        MyRole:='MIS Invoice Support';
        send_email (Sender, Receiver, Subject, Message2, MyRole);

     end if;

   Subject:=Subject||' ('||CurrDB||')';

   Receiver:='chao.ctr.yu@faa.gov';
   MyRole:='KITT Technical Support';
   send_email (Sender, Receiver, Subject, Message2,MyRole);

    if  MyStatus < 4 then

           MyRole:='CTR BUSINESS OPS';


           select C_CONTRACT_NUMBER, C_CONTRACT_NAME into ContractNum, ContractName
             from CONTRACT
            where N_CONTRACT_ID = MyKITTContractID;


            select N_INVOICE_ID,N_INVOICE_YEAR_MONTH into InvoiceID ,InvoicePeriod
            from INVOICE
            where C_MIS_INVOICE_NUMBER = MyMISInvoiceNum;

            if InvoiceID = MyMISInvoiceNum then
                InvoiceNumDesc := MyMISInvoiceNum;
            else
                InvoiceNumDesc := InvoiceID||' (MIS: '||MyMISInvoiceNum||')';
            end if;

           Subject:='KITT Notification - Contract: '||ContractNum||' Invoice: '||InvoiceNumDesc||' Period: '||InvoicePeriod||' is ready for review';


           Message2:= '<table><tr><td>KITT has received a new invoice for Contract: '||ContractNum||' Invoice: '||InvoiceNumDesc||' Period: '||InvoicePeriod||'.</td></tr>'
                   ||'<tr><td>The invoice is now is ready for review and Invoice Voucher Creation. </td></tr>'
                   ||'<tr><td>You have received this e-mail due to your role as CTR BUSINESS OPS in the <a href="http://kitt.faa.gov">KITT</a> system. </td></tr>'
                   ||'<tr><td><br><br>If you have any questions about KITT or have received this e-mail in error, please contact the <a href="mailto:9-ATOW-HQ-NISC-KittHelp@faa.gov">KITT System Administrator</a>. </td></tr><table>';

        If CurrDB = 'NISC3_PROD' then

           for c in ( select distinct lower(trim(b.C_EMAIL_ADDRESS)) as C_EMAIL_ADDRESS
                        from USER_ROLE a, USER_PROFILE b
                       where a.N_USER_PROFILE_ID=b.N_USER_PROFILE_ID
                         and a.N_ROLE_NUMBER = 117
                         and b.C_EMAIL_ADDRESS is not null) loop


                   Receiver:=trim(c.C_EMAIL_ADDRESS);
                   send_email (Sender, Receiver, Subject, Message2, MyRole);

           end loop;

         end if;

        Subject:=Subject||' ('||CurrDB||')';
        Receiver:='chao.ctr.yu@faa.gov';
        send_email (Sender, Receiver, Subject, Message2,MyRole);


     end if;




EXCEPTION
   WHEN OTHERS then
    null;
END;

  /* Handle on sub task order  level */

/*
PROCEDURE     INVOICE_SEND_PMO_NTP_EMAIL (MyInvoiceID number)

IS

/******************************************************************************
   NAME:       INVOICE_SEND_PMO_NTP_EMAIL
   PURPOSE:   Send an email notification after CTR BUSINESS OPS signs
              the invoice voucher and if there is valid NTP exist:


   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/28/2010  Chao Yu        1. Created this procedure.

******************************************************************************/
/*
   Sender             VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Receiver           VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Subject            VARCHAR2 (500)  := ' ';
   Message1           VARCHAR2 (1000) := ' ';
   Message2           VARCHAR2 (4000);
   ctn                number;
   MyRole             varchar2(100);
   CurrDB             varchar2(20);

BEGIN




        select count(N_INVOICE_ITEM_ID) into ctn
           from INVOICE_ITEM_WARNING_MSG
          where N_INVOICE_ID =MyInvoiceID
              and C_PROBLEM_ITEM ='Insufficient funds'
              and C_TYPE ='AUDIT'
              and F_OVERRIDE_FLAG = 'Y';


    if ctn > 0 then

          Subject:='The insufficient funding flags are overridden by NTP for the invoice '||to_char(MyInvoiceID);
         Message1:='<b>Notification for insufficient funding flags overridden:</b><br><br>'
                 ||'The following subtasks have insufficient funding, but the warning flag has been bypassed by a Notice to Proceed in the invoice '||to_char(MyInvoiceID)||'.<br><br>'
                 ||'<table width="90%"><tr><td><b>Task Order</b></td><td><b>Sub Task Order</b></td><td><b>Total Pending <br> Invoice Amount</b></td><td><b>Available Amount</b></td><td><b>Shortage Amount</b></td><td><b>NTP#</b></td><td><b>Creation Date</b></td></tr>';



         Message2:=Message1;
              for p  in (SELECT A.C_TASK_ORDER_NUMBER,
                               B.C_SUB_TASK_ORDER_NAME,
                               C.SUB_TASK_PENDING_AMOUNT as TOTAL_PENDING_INVOICE_AMOUNT,
                               C.SUB_TASK_ETO_AVAIL_AMOUNT AS AVAILABLE_AMOUNT,
                               C.SUB_TASK_AVAILABLE_AMOUNT AS SHORTAGE,
                               D.N_NTP_ID as NTP_NUM,
                               D.D_CREATED as CREATED_DATE
                          FROM TASK_ORDER A,
                               SUB_TASK_ORDER B,
                               V_KITTV_SUBTO_AVAILABLE_AMOUNT C,
                               NTP D,
                               NTP_SUBTASK E
                         WHERE A.N_TASK_ORDER_ID = B.N_TASK_ORDER_ID
                           AND B.N_TASK_ORDER_BASE_ID=C.N_TASK_ORDER_BASE_ID
                           AND Upper(trim(B.C_SUB_TASK_ORDER_NAME)) =Upper(trim(C.C_SUB_TASK_ORDER_NAME))
                           AND B.N_TASK_ORDER_BASE_ID=E.N_TASK_ORDER_BASE_ID
                           AND Upper(trim(B.C_SUB_TASK_ORDER_NAME)) =Upper(trim(E.C_SUB_TASK_ORDER_NAME))
                           AND E.N_NTP_ID = D.N_NTP_ID
                           AND D.N_OWNERSHIP_NUMBER in ( 204, 205)
                           AND B.N_SUB_TASK_ORDER_ID in (SELECT distinct m.N_SUB_TASK_ORDER_ID
                                                                                FROM INVOICE_ITEM m, INVOICE_ITEM_WARNING_MSG n
                                                                              WHERE n.N_INVOICE_ID =MyInvoiceID
                                                                                  AND m.N_INVOICE_ITEM_ID = n.N_INVOICE_ITEM_ID
                                                                                  AND n.C_PROBLEM_ITEM ='Insufficient funds'
                                                                                  AND n.C_TYPE ='AUDIT'
                                                                                  AND n.F_OVERRIDE_FLAG ='Y')
                      ORDER BY A.C_TASK_ORDER_NUMBER,B.C_SUB_TASK_ORDER_NAME,CREATED_DATE desc) loop



        Message2:=Message2
                ||'<tr><td>'||p.C_TASK_ORDER_NUMBER||'</td>'
                ||'    <td>'||p.C_SUB_TASK_ORDER_NAME||'</td>'
                ||'    <td>'||to_char(p.TOTAL_PENDING_INVOICE_AMOUNT,'$999,999,990.99')||'</td>'
                ||'    <td>'||to_char(p.AVAILABLE_AMOUNT,'$999,999,990.99')||'</td>'
                ||'    <td>'||to_char(p.SHORTAGE,'$999,999,990.99')||'</td>'
                ||'    <td>'||p.NTP_NUM||'</td>'
                ||'    <td>'||to_char(p.CREATED_DATE,'MM/DD/YYYY')||'</td></tr>';


      end loop;

      Message2:=Message2 ||'</td></tr></table>'
               ||'<br><br>You have received this email due to your role as PMO in the KITT system. If you have any questions about KITT or have received this email in error, '
               ||'please contact the <a href="mailto:9-ATOW-HQ-NISC-KittHelp@faa.gov">KITT System Administrator</a><br><br>'
               ||'Thank you.';


   CurrDB := GET_ENV_NAME ;
   MyRole:='PMO';

   If CurrDB = 'NISC3_PROD' then


           Receiver:='Suzy.CTR.Ferger@faa.gov';
           send_email (Sender, Receiver, Subject, Message2,MyRole);
           Receiver:='Andrey.CTR.Domansky@faa.gov';
           send_email (Sender, Receiver, Subject, Message2,MyRole);
           Receiver:='woody.ctr.long@faa.gov';
           send_email (Sender, Receiver, Subject, Message2,MyRole);
   else
        Subject := Subject ||' ('||CurrDB||')';
        Receiver:='David.CTR.Dixon-Peugh@faa.gov';
        send_email (Sender, Receiver, Subject, Message2,MyRole);
        Receiver:='Greg.CTR.Mangiapane@faa.gov';
        send_email (Sender, Receiver, Subject, Message2,MyRole);
        Receiver:='Kyle.CTR.Binns@faa.gov';
        send_email (Sender, Receiver, Subject, Message2,MyRole);
        Receiver:='Abu.ctr.Sarkar@faa.gov';
        send_email (Sender, Receiver, Subject, Message2,MyRole);


   end if;

   Receiver:='chao.ctr.yu@faa.gov';
   send_email (Sender, Receiver, Subject, Message2,MyRole);


 end if;

EXCEPTION
   WHEN OTHERS then
    -- dbms_output.put_line(to_char(SQLCODE) ||'-'||SQLERRM);
   null;
END;
*/

--  For Old Task Order Level
PROCEDURE     INVOICE_SEND_PMO_NTP_EMAIL_MSG (
                                                                sender     IN   VARCHAR2,
                                                                receiver   IN   VARCHAR2,
                                                                subject    IN   VARCHAR2,
                                                                MESSAGE    IN   VARCHAR2,
                                                                MyInvoiceID IN NUMBER)
IS
/******************************************************************************
   NAME:       INVOICE_SEND_PMO_NTP_EMAIL_MSG
   PURPOSE:   Send a large email notification after CTR BUSINESS OPS signs
              the invoice voucher and if there is valid NTP exist:


   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      05/23/2011  Chao Yu         1. Add this private procedure to handle larger email to fix the issue for ticket NISCIII-576

******************************************************************************/
conn   UTL_SMTP.connection;
crlf     VARCHAR2 (2)        := CHR (13) || CHR (10);
HeaderMsg  VARCHAR2 (4000);
PortionBodyMsg VARCHAR2(4000):=' ';

BEGIN



         conn := UTL_SMTP.open_connection ('204.108.10.6', 25);
         UTL_SMTP.helo (conn, '204.108.10.6');
         UTL_SMTP.mail (conn, sender);
         UTL_SMTP.rcpt (conn, receiver);
         UTL_SMTP.open_data(conn);


         HeaderMsg := 'Content-Type: text/html; charset="US-ASCII" '
                           || 'Date: '
                           || TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss')
                           || crlf
                           || 'From: KITT System'
                           || crlf
                           || 'Subject: '
                           || subject
                           || crlf
                           || 'To: '
                           || receiver
                           || crlf
                           || crlf
                           || MESSAGE
                           || crlf
                           || crlf;

          UTL_SMTP.write_data (conn,  HeaderMsg);

          PortionBodyMsg:='The following subtasks have insufficient funding, but the warning flag has been bypassed by a Notice to Proceed in the invoice '||to_char(MyInvoiceID)||'.<br><br>'
                                 ||'<table width="90%"><tr><td><b>Task Order</b></td><td><b>Sub Task Order</b></td><td><b>Total Pending <br> Invoice Amount</b></td><td><b>Available Amount</b></td><td><b>Shortage Amount</b></td><td><b>NTP#</b></td><td><b>Creation Date</b></td></tr>';
         UTL_SMTP.write_data (conn, PortionBodyMsg);

            for p  in (SELECT distinct
                               B.C_TASK_ORDER_NUMBER,
                               B.C_SUB_TASK_ORDER_NAME,
                               C.SUB_TASK_PENDING_AMOUNT as TOTAL_PENDING_INVOICE_AMOUNT,
                               C.SUB_TASK_ETO_AVAIL_AMOUNT AS AVAILABLE_AMOUNT,
                               C.SUB_TASK_AVAILABLE_AMOUNT AS SHORTAGE,
                               D.N_NTP_ID as NTP_NUM,
                               D.D_CREATED as CREATED_DATE
                          FROM TASK_ORDER A,
                                   V_KITTV_FULL_LOOKUP_SUBTASK B,
                                   V_KITTV_SUBTO_AVAILABLE_AMOUNT C,
                                   NTP D
                         WHERE A.N_TASK_ORDER_BASE_ID = B.N_TASK_ORDER_BASE_ID
                           AND B.N_TASK_ORDER_BASE_ID=C.N_TASK_ORDER_BASE_ID
                           AND B.C_SUB_TASK_ORDER_NAME =C.C_SUB_TASK_ORDER_NAME
                           AND A.N_TASK_ORDER_ID = D.N_OBJECT_ID
                           AND D.N_OWNERSHIP_NUMBER in ( 204, 205)
                           AND C.SUB_TASK_AVAILABLE_AMOUNT < 0
                           AND A.N_TASK_ORDER_BASE_ID in (SELECT distinct m.N_TASK_ORDER_BASE_ID
                                                                              FROM INVOICE_ITEM m, INVOICE_ITEM_WARNING_MSG n
                                                                              WHERE n.N_INVOICE_ID =MyInvoiceID
                                                                                   AND m.N_INVOICE_ITEM_ID = n.N_INVOICE_ITEM_ID
                                                                                   AND n.F_OVERRIDE_FLAG ='Y'
                                                                                   and n.C_PROBLEM_ITEM ='Insufficient funds'
                                                                                   and n.C_TYPE ='AUDIT')
                      ORDER BY to_number(B.C_TASK_ORDER_NUMBER),B.C_SUB_TASK_ORDER_NAME,CREATED_DATE desc) loop

               PortionBodyMsg:='<tr><td>'||p.C_TASK_ORDER_NUMBER||'</td>'
                                         ||'    <td>'||p.C_SUB_TASK_ORDER_NAME||'</td>'
                                         ||'    <td>'||to_char(p.TOTAL_PENDING_INVOICE_AMOUNT,'$999,999,990.99')||'</td>'
                                         ||'    <td>'||to_char(p.AVAILABLE_AMOUNT,'$999,999,990.99')||'</td>'
                                         ||'    <td>'||to_char(p.SHORTAGE,'$999,999,990.99')||'</td>'
                                         ||'    <td>'||p.NTP_NUM||'</td>'
                                         ||'    <td>'||to_char(p.CREATED_DATE,'MM/DD/YYYY')||'</td></tr>';

               UTL_SMTP.write_data (conn, PortionBodyMsg);

      end loop;

      PortionBodyMsg:='</td></tr></table>'
               ||'<br><br>You have received this email due to your role as PMO in the KITT system. If you have any questions about KITT or have received this email in error, '
               ||'please contact the <a href="mailto:9-ATOW-HQ-NISC-KittHelp@faa.gov">KITT System Administrator</a><br><br>'
               ||'Thank you.';

       UTL_SMTP.write_data (conn, PortionBodyMsg);
       UTL_SMTP.close_data(conn);
       UTL_SMTP.quit (conn);

    EXCEPTION
         WHEN OTHERS then
           PK_INVOICE_LOADING .INVOICE_SEND_SUPPORT_EMAIL ( MyInvoiceID, null, 'NTP OVERWRITTEN', 'Error In INVOICE_SEND_PMO_NTP_EMAIL_MSG:'||to_char(SQLCODE) ||'-'||SQLERRM||'.');
          dbms_output.put_line( 'Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.');
END;

PROCEDURE     INVOICE_SEND_PMO_NTP_EMAIL (MyInvoiceID number)

IS

/******************************************************************************
   NAME:       INVOICE_SEND_PMO_NTP_EMAIL
   PURPOSE:   Send an email notification after CTR BUSINESS OPS signs
              the invoice voucher and if there is valid NTP exist:


   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/28/2010  Chao Yu        1. Created this procedure.
   2.0      03/16/2011  Chao Yu         2. Fix the issue for ticket NISCIII -505
   3.0      05/23/2011  Chao Yu         3. Fix the issue for ticket NISCIII-576

   -- 03/16/2011 fix to ticket NISCIII-505
  -- If we execute the overwritten on task order level for both new sub task order NTP and legacy task order level NTP.
  -- It will work for legacy NTPs, but may overwitten more invoice items for the new NTP which is created on sub task order level
  -- But PMO Woody requested and  Sjawn approved  to overwritten flag on task order level for both new sub task order NTP and legacy task order level NTP.


******************************************************************************/

   Sender             VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Receiver           VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Subject            VARCHAR2 (500)  := ' ';
   SubjectEnv       VARCHAR2 (500)  := ' ';
   Message          VARCHAR2 (4000);
   ctn                number;
   MyRole             varchar2(100);
   CurrDB             varchar2(20);

BEGIN

           CurrDB := GET_ENV_NAME ;
           MyRole:='PMO';

         select count(*) into ctn
          from (SELECT distinct
                               B.C_TASK_ORDER_NUMBER,
                               B.C_SUB_TASK_ORDER_NAME,
                               C.SUB_TASK_PENDING_AMOUNT as TOTAL_PENDING_INVOICE_AMOUNT,
                               C.SUB_TASK_ETO_AVAIL_AMOUNT AS AVAILABLE_AMOUNT,
                               C.SUB_TASK_AVAILABLE_AMOUNT AS SHORTAGE,
                               D.N_NTP_ID as NTP_NUM,
                               D.D_CREATED as CREATED_DATE
                          FROM TASK_ORDER A,
                                   V_KITTV_FULL_LOOKUP_SUBTASK B,
                                   V_KITTV_SUBTO_AVAILABLE_AMOUNT C,
                                   NTP D
                         WHERE A.N_TASK_ORDER_BASE_ID = B.N_TASK_ORDER_BASE_ID
                           AND B.N_TASK_ORDER_BASE_ID=C.N_TASK_ORDER_BASE_ID
                           AND B.C_SUB_TASK_ORDER_NAME =C.C_SUB_TASK_ORDER_NAME
                           AND A.N_TASK_ORDER_ID = D.N_OBJECT_ID
                           AND D.N_OWNERSHIP_NUMBER in ( 204, 205)
                           AND C.SUB_TASK_AVAILABLE_AMOUNT < 0
                           AND A.N_TASK_ORDER_BASE_ID in (SELECT distinct m.N_TASK_ORDER_BASE_ID
                                                                              FROM INVOICE_ITEM m, INVOICE_ITEM_WARNING_MSG n
                                                                              WHERE n.N_INVOICE_ID =MyInvoiceID
                                                                                   AND m.N_INVOICE_ITEM_ID = n.N_INVOICE_ITEM_ID
                                                                                   AND n.F_OVERRIDE_FLAG ='Y'
                                                                                   and n.C_PROBLEM_ITEM ='Insufficient funds'
                                                                                   and n.C_TYPE ='AUDIT'));

    if ctn > 0 then

          Subject:='The insufficient funding flags are overridden by NTP for the invoice '||to_char(MyInvoiceID);
          SubjectEnv:=Subject ||' ('||CurrDB||')';
          Message:='<b>Notification for insufficient funding flags overridden:</b><br><br>';

         If CurrDB = 'NISC3_PROD' then

           Receiver:='Suzy.CTR.Ferger@faa.gov';
           INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender, Receiver,Subject,Message, MyInvoiceID);
           Receiver:='Andrey.CTR.Domansky@faa.gov';
           INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender, Receiver,Subject,Message, MyInvoiceID);
           Receiver:='woody.ctr.long@faa.gov';
           INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender, Receiver,Subject,Message, MyInvoiceID);

       else

        Receiver:='Greg.CTR.Mangiapane@faa.gov';
        INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender,Receiver,SubjectEnv, Message, MyInvoiceID);
        Receiver:='Abu.ctr.Sarkar@faa.gov';
        INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender, Receiver,SubjectEnv, Message, MyInvoiceID);

      end if;

       Receiver:='chao.ctr.yu@faa.gov';
       INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender, Receiver,SubjectEnv, Message, MyInvoiceID);
       Receiver:='David.CTR.Dixon-Peugh@faa.gov';
       INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender, Receiver,SubjectEnv, Message, MyInvoiceID);
       Receiver:='Jon.CTR.Goff@faa.gov';
       INVOICE_SEND_PMO_NTP_EMAIL_MSG ( Sender, Receiver,SubjectEnv, Message, MyInvoiceID);


   else


         Subject:='The insufficient funding flags are overridden by NTP for the invoice '||to_char(MyInvoiceID);
         SubjectEnv:=Subject ||' ('||CurrDB||')';
         Message:='<b> Notification for insufficient funding flags overridden:</b><br><br>'
                      ||' No subtasks with insufficient funding warning flag has been bypassed by a Notice to Proceed in the invoice '||to_char(MyInvoiceID)||'.<br><br>'
                      ||'<br><br>You have received this email due to your role as PMO in the KITT system. If you have any questions about KITT or have received this email in error, '
                      ||'please contact the <a href="mailto:9-ATOW-HQ-NISC-KittHelp@faa.gov">KITT System Administrator</a><br><br>'
                      ||'Thank you.';

        If CurrDB = 'NISC3_PROD' then

           Receiver:='Suzy.CTR.Ferger@faa.gov';
           send_email (Sender, Receiver, Subject, Message,MyRole);
           Receiver:='Andrey.CTR.Domansky@faa.gov';
           send_email (Sender, Receiver, Subject, Message,MyRole);
           Receiver:='woody.ctr.long@faa.gov';
           send_email (Sender, Receiver, Subject, Message,MyRole);

       else

        Receiver:='Greg.CTR.Mangiapane@faa.gov';
        send_email (Sender, Receiver, SubjectEnv, Message,MyRole);
        Receiver:='Abu.ctr.Sarkar@faa.gov';
        send_email (Sender, Receiver, SubjectEnv, Message,MyRole);

      end if;


     Receiver:='chao.ctr.yu@faa.gov';
     send_email (Sender, Receiver, SubjectEnv, Message,MyRole);
     Receiver:='David.CTR.Dixon-Peugh@faa.gov';
     send_email (Sender, Receiver, SubjectEnv, Message,MyRole);
     Receiver:='Jon.CTR.Goff@faa.gov';
     send_email (Sender, Receiver, SubjectEnv, Message,MyRole);

 end if;

EXCEPTION
   WHEN OTHERS then
           PK_INVOICE_LOADING .INVOICE_SEND_SUPPORT_EMAIL ( MyInvoiceID, null, 'NTP OVERWRITTEN', 'Error In INVOICE_SEND_PMO_NTP_EMAIL:'||to_char(SQLCODE) ||'-'||SQLERRM||'.');
          dbms_output.put_line( 'Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.');

END;


PROCEDURE  INVOICE_SEND_VOUCHER_EMAIL (
                                         MyKITTContractNum varchar2,
                                         MyInvoiceID     number)

IS

/******************************************************************************
   NAME:       INVOICE_SEND_VOUCHER_EMAIL
   PURPOSE:   Send an email notification after CTR BUSINESS OPS
              signs the invoice voucher


   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/28/2010  Chao Yu        1. Created this procedure.

******************************************************************************/

   crlf               VARCHAR2 (2)    := CHR (13) || CHR (10);
   Sender             VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Receiver           VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Subject            VARCHAR2 (500)  := ' ';
   Message            VARCHAR2 (2000) := ' ';
   Message1            VARCHAR2 (2000) := ' ';

   ctn                number;
   MyRole             varchar2(100);
   CurrDB             varchar2(20);
   ContractNum        varchar2(50);
   ContractName       varchar2(200);
   InvoiceTotal       number;
   ActionTaken        varchar2(30);

BEGIN


           MyRole:='CTR BUSINESS OPS';

           Subject:='KITT New Invoice Notification';


            select C_CONTRACT_NUMBER, C_CONTRACT_NAME into ContractNum, ContractName
             from CONTRACT
            where upper(trim(C_CONTRACT_NUMBER)) = upper(trim(MyKITTContractNum));

           select round(sum(N_FAA_COST),2) into InvoiceTotal
            from INVOICE_ITEM
            where N_INVOICE_ID =MyInvoiceID;


        Message:=
          '<table><tr><td><b>KITT New Invoice Notification:</b></td></tr>'
        ||'<tr><td><br>KITT has received a new invoice for Contract Number: '||ContractNum||', Contract Name: '||ContractName||'. </td></tr>'
        ||'<tr><td>Invoice Number '||to_char(MyInvoiceID)||', dated '||to_char(sysdate,'MM/DD/YYYY')
        ||' for the Amount of '||to_char(InvoiceTotal, '$999,999,999.99')||' is ready for Accounts Payable review and acceptance.</td></tr>';



    CurrDB := GET_ENV_NAME ;

     If CurrDB = 'NISC3_PROD' then

           for p in ( select distinct lower(trim(b.C_EMAIL_ADDRESS)) as C_EMAIL_ADDRESS, c.C_ROLE_LABEL
                        from USER_ROLE a, USER_PROFILE b, SYSTEM_ROLE c
                       where a.N_USER_PROFILE_ID=b.N_USER_PROFILE_ID
                         and a.N_ROLE_NUMBER = c.N_ROLE_NUMBER
                         and a.N_ROLE_NUMBER in ( 200,111)
                         and b.C_EMAIL_ADDRESS is not null) loop

                   Message1:=' ';

                   if p.C_ROLE_LABEL = 'A/P' then

                      ActionTaken:='accept';

                   else

                      ActionTaken:='review';

                   end if;

                      Message1:= Message
                            ||'<tr><td>Please login to <a href="http://kitt.faa.gov">KITT</a> and '||ActionTaken||' the invoice.</td></tr>'
                            ||'<tr><td>You have received this email due to your role as '||p.C_ROLE_LABEL||' in the KITT system. If you have any questions about KITT or have received this email in error, '
                            ||'please contact the <a href="mailto:9-ATOW-HQ-NISC-KittHelp@faa.gov">KITT System Administrator</a>.</td></tr>'
                            ||'<tr><td><br><br>Thank you</td></tr></table>';


                   Receiver:=trim(p.C_EMAIL_ADDRESS);
                   send_email (Sender, Receiver, Subject, Message1, MyRole);

           end loop;

    end if;

        If CurrDB = 'NISC3_DEV' or CurrDB = 'NISC3_TEST' then


          Subject:='KITT New Invoice Notification ('||CurrDB||')';

           for p in ( select distinct lower(trim(b.C_EMAIL_ADDRESS)) as C_EMAIL_ADDRESS, c.C_ROLE_LABEL
                        from USER_ROLE a, USER_PROFILE b, SYSTEM_ROLE c
                       where a.N_USER_PROFILE_ID=b.N_USER_PROFILE_ID
                         and a.N_ROLE_NUMBER = c.N_ROLE_NUMBER
                         and a.N_ROLE_NUMBER in ( 200,111)
                         and b.C_USER_NAME in ('Kyle.CTR.Binns','Chao CTR YU','Greg CTR Mangiapane')
                         and b.C_EMAIL_ADDRESS is not null) loop

                   Message1:=' ';

                   if p.C_ROLE_LABEL = 'A/P' then

                      ActionTaken:='accept';

                   else

                      ActionTaken:='review';

                   end if;

                        Message1:= Message
                            ||'<tr><td>Please login to <a href="http://kitt.faa.gov">KITT</a> and '||ActionTaken||' the invoice.</td></tr>'
                            ||'<tr><td>You have received this email due to your role as '||p.C_ROLE_LABEL||' in the KITT system. If you have any questions about KITT or have received this email in error, '
                            ||'please contact the <a href="mailto:9-ATOW-HQ-NISC-KittHelp@faa.gov">KITT System Administrator</a>.</td></tr>'
                            ||'<tr><td><br><br>Thank you</td></tr></table>';

                   Receiver:=trim(p.C_EMAIL_ADDRESS);
                   send_email (Sender, Receiver, Subject, Message1, MyRole);

           end loop;

    end if;

           If CurrDB = 'NISC3_BETA'  then

                      Subject:='KITT New Invoice Notification ('||CurrDB||')';
                      ActionTaken:='review';

                        Message1:= Message
                            ||'<tr><td>Please login to <a href="http://kitt.faa.gov">KITT</a> and '||ActionTaken||' the invoice.</td></tr>'
                            ||'<tr><td>You have received this email due to your role as CTR BUSINESS OPS in the KITT system. If you have any questions about KITT or have received this email in error, '
                            ||'please contact the <a href="mailto:9-ATOW-HQ-NISC-KittHelp@faa.gov">KITT System Administrator</a>.</td></tr>'
                            ||'<tr><td><br><br>Thank you</td></tr></table>';

                   Receiver:='chao.ctr.yu@faa.gov';
                   send_email (Sender, Receiver, Subject, Message1, MyRole);

    end if;

   INVOICE_SEND_PMO_NTP_EMAIL (MyInvoiceID);


EXCEPTION
   WHEN OTHERS then

    null;
END;

PROCEDURE  INVOICE_SEND_SUPPORT_EMAIL (
                                         MyKITTInvoiceID number,
                                         MyMISInvoiceNum varchar2 ,
                                         MySupportType varchar2,
                                         MyMsg varchar2)

IS

/******************************************************************************
   NAME:       INVOICE_SEND_SUPPORT_EMAIL
   PURPOSE:   Send an email notification to tech support if some actions failed

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      04/15/2011  Chao Yu        1. Created this procedure.

******************************************************************************/

   crlf               VARCHAR2 (2)    := CHR (13) || CHR (10);
   Sender             VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Receiver           VARCHAR2 (500)  := 'chao.ctr.yu@faa.gov';
   Subject            VARCHAR2 (500)  := ' ';
   Message            VARCHAR2 (2000) := ' ';
   MyRole             varchar2(100);
   CurrDB             varchar2(20);


BEGIN
           MyRole:='Tech Support';

         if   MySupportType = 'INVOICE AUDIT' then

               Subject:='Invoice Audit failed in NISCIII';
               Message:= 'Invoice audit (Contract: NISCIII; MIS invoice number: '|| MyMISInvoiceNum||') was failed! ' || crlf ||MyMsg;

        elsif MySupportType = 'NTP OVERWRITTEN' then

               Subject:='Invoice NTP Overwritten email failed in NISCIII';
               Message:= 'NTP Overwritten email notification (Contract: NISCIII, KITT invoice ID: '||to_char(MyKITTInvoiceID)||') was failed!'|| crlf  ||MyMsg;

        elsif MySupportType = 'RECONCILIATION' then

               Subject:='RECONCILIATION Failed in NISCIII';
               Message:= 'RECONCILIATION for contract NISCIII was failed! '|| crlf  ||MyMsg;

      else

               Subject:='Error in NISCIII';
               if MyKITTInvoiceID is null then
                  Message:= 'Error for contract: NISCIII, invoice number: '|| MyMISInvoiceNum  ||' was failed! ' || crlf  ||MyMsg;
               else
                  Message:= 'Error for contract: NISCIII, invoice number: '||to_char( MyKITTInvoiceID) ||' was failed! ' || crlf  ||MyMsg;

               end if;

         end if;


    CurrDB := GET_ENV_NAME ;

    Subject:=Subject||' ('||CurrDB||')';

     If CurrDB = 'NISC3_PROD' or CurrDB = 'NISC3_DEV' then

           for p in ( select distinct lower(trim(C_EMAIL_DEVELOPER )) as C_EMAIL_ADDRESS
                        from EMAIL_RECIPIENTS
                        where C_EMAIL_DEVELOPER is not null) loop

                   Receiver:=trim(p.C_EMAIL_ADDRESS );
                   send_email (Sender, Receiver, Subject, Message, MyRole);

           end loop;

    end if;

      Receiver:='chao.ctr.yu@faa.gov';
      send_email (Sender, Receiver, Subject, Message, MyRole);


EXCEPTION
   WHEN OTHERS then
    null;
END;


PROCEDURE           INVOICE_UPDATE_CONTRACTOR

IS

/******************************************************************************
   NAME:       INVOICE_UPDATE_CONTRACTOR
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0     07/28/2010     Chao Yu      1. Created this procedure.

   NOTES:


******************************************************************************/

ctn number;

BEGIN


     for c in (select COMPANY,NAME,HOURS,BILLING
                 from V_MIS_CONTRACTOR a) loop

         select count(*) into ctn from CONTRACTOR a
         where trim(a.C_CONTRACTOR_LABEL) = trim(c.COMPANY);

         if ctn = 0 then

            insert into CONTRACTOR (
                     N_CONTRACTOR_ID,
                     C_CONTRACTOR_LABEL,
                     T_COMMENTS,
                     C_NAME,
                     C_CONTRACT_TYPE,
                     C_BILLING_TYPE)
               values( SEQ_CONTRACTOR.nextval,
                     trim(c.COMPANY),
                     trim(c.NAME),
                     trim(c.NAME),
                     trim(c.HOURS),
                     trim(c.BILLING));

           --dbms_output.PUT_LINE('Add Contractor: ' ||c.COMPANY);


         end if;



     end loop;

     commit;

     for c in (select b.N_CONTRACTOR_ID,
                      trim(a.period) as C_PERIOD,
                      a.allowable_hours as N_ALLOWABLE_HOURS
               from V_MIS_CONTRACTOR_HOURS a,
                    CONTRACTOR b
               where trim(a.contractor) = trim(b.C_CONTRACTOR_LABEL)) loop


           select count(*) into ctn
             from CONTRACTOR_HOURS
             where N_CONTRACTOR_ID = c.N_CONTRACTOR_ID
               and C_PERIOD =c.C_PERIOD;

           if ctn  = 0 then

               insert into CONTRACTOR_HOURS ( N_CONTRACTOR_ID,C_PERIOD,N_ALLOWABLE_HOURS)
                values ( c.N_CONTRACTOR_ID,c.C_PERIOD,c.N_ALLOWABLE_HOURS );

           end if;


      end loop;

      commit;


     for c in (  select b.N_contractor_id, a.period, a.inv_start, a.inv_end, a.inv_hours, a.HOUR_TYPE,a.MAX_HOURS
                   from V_MIS_CONTRACTOR_CALENDAR a,
                        CONTRACTOR b
                  where trim(a.contractor) = trim(b.C_CONTRACTOR_LABEL)) loop

         select count(*) into ctn from HOURS_SCHEDULE
          where N_CONTRACTOR_ID = c.N_contractor_id
            and C_PERIOD = c.period;

         if ctn = 0 then

            insert into HOURS_SCHEDULE
             ( N_HOURS_ID,
               N_CONTRACTOR_ID,
               C_PERIOD,
               D_INVOICE_START_DATE,
               D_INVOICE_END_DATE,
               N_INVOICE_HOURS,
               N_ALLOWABLE_HOURS,
               C_CONTRACT_TYPE)
             values
              (SEQ_HOURS_SCHEDULE.nextval,
               c.N_contractor_id,
               c.period,
               c.inv_start,
               c.inv_end,
               c.inv_hours,
               c.MAX_HOURS,
               c.HOUR_TYPE);

              -- dbms_output.PUT_LINE('Add Hour: ' ||c.CONTRACTOR);

         end if;


     end loop;

     commit;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END INVOICE_UPDATE_CONTRACTOR;


PROCEDURE     INVOICE_UPDATE_LOADING_STATUS (
                                        MyInvoiceNum number,
                                        MyStatus number)


IS

/******************************************************************************
   NAME:       UPDATE_LOADING_STATUS
   PURPOSE:    Update the invoice loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        07/28/2010  Chao Yu       1. Created this procedure.

   NOTES:

******************************************************************************/
BEGIN

   Update V_MIS_INVOICE_PULLING_STATUS
      set N_STATE_ID = MyStatus,
          UPDATE_DATE = sysdate
    where  N_INVOICE_NUM = MyInvoiceNum;
    commit;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END;


PROCEDURE    INVOICE_UPDATE_WARNING_FLAG (MyInvoiceItemID number)
IS

/******************************************************************************
   NAME:       INVOICE_UPDATE_WARNING_FLAG

   PURPOSE:    This stored procedure update F_Warning_Flag to 'Y'
               in INVOICE_ITEM table.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        01/13/2009  Chao Yu        1. Created this function.

******************************************************************************/


BEGIN

             update INVOICE_ITEM
                set F_WARNING_FLAG ='Y'
              where N_INVOICE_ITEM_ID = MyInvoiceItemID;
              commit;



EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Raise;
END;


PROCEDURE    INVOICE_VERIFY_COMPANY(
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyCompanyStr varchar2,
                                           MyStatus in out number)


IS

/******************************************************************************
   NAME:       INVOICE_VERIFY_COMPANY
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0       07/28/2010   Chao Yu      1. Created this procedure.



******************************************************************************/

ctn number:=0;
Msg varchar2(4000);

BEGIN



   if NVL(MyCompanyStr,'N/A') = 'N/A' then  -- missing company data in invoice record.

        INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Company',
                                       null,
                                       'Failed',
                                       'Missing company information.');


         if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
         end if;

    end if;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Company',
                                       MyCompanyStr,
                                       'Failed',
                                       Msg);

       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
       end if;

END;


PROCEDURE   INVOICE_VERIFY_COST_TYPE_ID (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyCostTypeID in out number,
                                           MyStatus in out number)
IS

/******************************************************************************
   NAME:       INVOICE_VERIFY_COST_TYPE_ID
   PURPOSE:    Validate cost type ID is valid ID in KITT.
               return loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        07/28/2010  Chao Yu        1. Created this function.

******************************************************************************/


MyCostTypeStr varchar2(25);
ctn number:=0;
Msg varchar2(4000);

BEGIN




      select count(*) into ctn from COST_TYPE where N_COST_TYPE_ID =MyCostTypeID;


      if ctn = 0 then

         INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Cost Type ID',
                                       MyCostTypeID,
                                       'Failed',
                                       'Cost Type ID ('||MyCostTypeID||') is not valid ID.');


         if MyStatus < 4 then
           MyStatus:=4; -- Set to Warning status.
         end if;

         MyCostTypeID:=null;

      end if;




   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Cost Type ID',
                                        MyCostTypeID,
                                        'Failed',
                                        Msg);
       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
         end if;

       MyCostTypeID:=null;

END;


PROCEDURE  INVOICE_VERIFY_EMPLOYEE_ODC (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyLastNameStr varchar2,
                                           MyODCTypeID number,
                                           MyNISCNum number,
                                           MyNISCEntry number,
                                           MyLaborCateID number,
                                           MyExpLevelStr varchar2,
                                           MyCostTypeID number,
                                           MyStatus in out varchar2)
IS


/******************************************************************************
   NAME:        INVOICE_VERIFY_EMPLOYEE
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/29/2010    Chao Yu      1. Created this procedure.



******************************************************************************/


ctn number:=0;
Msg varchar2(4000);

BEGIN

  if MyCostTypeID = 103 then

            if NVL(MyODCTypeID,0) = 0 then

                INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'ODC_TYPE',
                                       null,
                                       'Warning',
                                       'Missing ODC_TYPE data.');


               if MyStatus < 3 then
                 MyStatus:=3; -- Set to Warning status.
               end if;

           end if;

   end if;

   if NVL(MyLastNameStr,'N/A') = 'N/A' then

       if MyCostTypeID != 106 and MyCostTypeID != 109 and MyCostTypeID != 103 then

                INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Employee Name',
                                       null,
                                       'Warning',
                                       'Missing Employee Name.');


               if MyStatus < 3 then
                 MyStatus:=3; -- Set to Warning status.
               end if;

      end if;


   else

     if MyNISCNum  = 0 or NVL(MyNISCEntry,0) = 0 then


         INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'NISCNum/Entry',
                                       null,
                                       'Warning',
                                       'Missing employee information.');


         if MyStatus < 3 then
           MyStatus:=3; -- Set to Warning status.
         end if;

      end if;



       if NVL(MyLaborCateID,0) =0 then

           INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Labor Category',
                                       null,
                                       'Warning',
                                       'Missing labor category information.');


         if MyStatus < 3 then
           MyStatus:=3; -- Set to Warning status.
         end if;

      end if;

      /*
       if MyExpLevelStr ='N/A' then

          INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Years Experience',
                                       null,
                                       'Warning',
                                       'Missing years experience information.');


         if MyStatus < 3 then
           MyStatus:=3; -- Set to Warning status.
         end if;



      end if;
       */

    end if;



     EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Employee/ODC',
                                       null,
                                       'Failed',
                                       Msg);

       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
       end if;

END;


PROCEDURE   INVOICE_VERIFY_LABOR_CATE_ID (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyLaborCateStr varchar2,
                                           MyLaborCateID in out number,
                                           MyStatus in out number)
IS

/******************************************************************************
   NAME:       INVOICE_VERIFY_LABOR_CATE_ID
   PURPOSE:    Validate labor category information.
               return loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0       07/29/2010  Chao Yu        1. Created this function.


******************************************************************************/


ctn number:=0;
Msg varchar2(4000);

BEGIN



   if MyLaborCateID = 0 then

      MyLaborCateID := null;

   else


      select count(*) into ctn
        from LABOR_CATEGORY
       where N_LABOR_CATEGORY_ID = MyLaborCateID;


      if ctn = 0 then -- It is a labor record, but this labor cate ID is not in KITTS labor_cate table.


          INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Labor Cate ID',
                                       MyLaborCateID,
                                       'Warning',
                                       'Labor Category '||MyLaborCateID|| ': '||MyLaborCateStr||' doesn''t exist.');

         MyLaborCateID := null;

         if MyStatus < 3 then
           MyStatus:=3; -- Set to Warning status.
         end if;



      end if;

    end if;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Labor Cate ID',
                                       MyLaborCateID,
                                       'Failed',
                                       Msg);

       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
       end if;

END;


PROCEDURE           INVOICE_VERIFY_ODC_TYPE_ID (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MyODCType varchar2,
                                           MyODCTypeID in out number,
                                           MyStatus in out number)
IS

/******************************************************************************
   NAME:       GET_ODC_TYPE_ID_NUM
   PURPOSE:    Validate ODC Type information. If ODC Type doesn't exist,
               then insert error message into log table.
               return ODCTypeID and loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        07/29/2010  Chao Yu        1. Created this function.

******************************************************************************/


MyODCTypeStr varchar2(50);
ctn number:=0;
Msg varchar2(4000);

BEGIN


   MyODCTypeStr:= Upper(trim(MyODCType));

   if MyODCTypeID = 0 then

          MyODCTypeID := null;
   else

      select count(*) into ctn
       from ODC_TYPE
      where N_ODC_TYPE_ID = MyODCTypeID;


      if ctn = 0 then -- It is a ODC record, but this ODC Type is not in KITTS ODC_Type table.

          MyODCTypeID := null;

          INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'ODC Type ID',
                                       MyODCTypeStr,
                                       'Warning',
                                       'ODC Type '||MyODCTypeID||': '||MyODCTypeStr||' doesn''t exist in KITT');

         if MyStatus < 3 then
           MyStatus:=3;
         end if;


      end if;

   end if;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'ODC Type ID',
                                       MyODCTypeStr,
                                       'Failed',
                                       Msg);

       if MyStatus < 4 then
           MyStatus:=4; -- Set to Failed status.
       end if;

END;


PROCEDURE   INVOICE_VERIFY_SUB_TO_ID (
                                           MyContractID number,
                                           MyInvoiceNum varchar2,
                                           MyLoadSeq number,
                                           MyMISInvoceID number,
                                           MySubTaskOrderID in out number,
                                           MyTaskOrderBaseID in out number,
                                           MySubTaskOrderName in out varchar2,
                                           MyStatus in out number)
IS

/******************************************************************************
   NAME:       GET_SUB_TASK_ORDER_ID_NUM
   PURPOSE:    Validate task order amd sub task order information.
               If task order or sub task order don't exist,
               then insert error message into log table.
               return sub task order id and loading status.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      07/29/2010  Chao Yu        1. Created this function.


******************************************************************************/

ctn number:=0;
Msg varchar2(4000);

BEGIN



     select count(*) into ctn
       from SUB_TASK_ORDER
      where N_SUB_TASK_ORDER_ID = MySubTaskOrderID
        and N_TASK_ORDER_BASE_ID = MyTaskOrderBaseID
        and C_SUB_TASK_ORDER_NAME = MySubTaskOrderName ;


   if  ctn = 0 then  -- Task Order and sub task order must be exist. Otherwise the invoice entry will not be loaded into invoice table.


          INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Sub Task Order',
                                       MySubTaskOrderID,
                                       'Failed',
                                       'Sub Task Order '||MyTaskOrderBaseID||'-'||MySubTaskOrderName||' doesn''t exist.');

          if MyStatus < 4 then
             MyStatus:=4; -- Set to Failed status.
          end if;

          MySubTaskOrderID:= null;
          MyTaskOrderBaseID:=null;
          MySubTaskOrderName:=null;

      end if;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
        Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
           INVOICE_LOG_MULTI_PARAM (
                                       MyContractID,
                                       MyInvoiceNum,
                                       MyLoadSeq,
                                       MyMISInvoceID,
                                       'Sub Task Order',
                                       MySubTaskOrderID||'('||MyTaskOrderBaseID||'-'||MySubTaskOrderName||')',
                                       'Failed',
                                       Msg);

       if MyStatus < 4 then
           MyStatus:=4;
         end if;

      MySubTaskOrderID:= null;
      MyTaskOrderBaseID:=null;
      MySubTaskOrderName:=null;

END;


PROCEDURE    INVOICE_ITEM_AUDIT (
                                           MyContractID number,
                                           MyInvoiceNum varchar2)
IS

/******************************************************************************
   NAME:     INVOICE_ITEM_AUDIT
   PURPOSE:  This procedure will audit following issues:

            1. Work period is later than bill period.
            2. Charge age is greater than six months.
            3. Charge is outside of the period of performance (to the subtask level)
            4. Charge is without description
            5. Hours invoiced is over company allowed
            6. Insufficient funds
            7. Duplicate charges

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0       08/02/2010  Chao Yu        1. Created this function.

******************************************************************************/


MySubTaskOrderStartDate date;
MySubTaskOrderEndDate date;
MyMaxHours number;
MyHours number;
MyPaidHours number;
MyPendingHours number;
DuplicateChargesItemIDStr varchar2(200);
SubTOAvailableFund number;
ctn number;
MyInvoiceID number;
MyDays number;
MyCompanyName varchar2 (50);
MyMSG varchar2 (500);
MyTaskOrderNum varchar2(10);
MySubTaskName varchar2(14);
MyFundShortage number;

MyProblemItem varchar2(100);
MyReason varchar2(4000);
MyType varchar2(15);

BEGIN

   -- clean up the existing audit messages first.

     select N_INVOICE_ID into MyInvoiceID
       from INVOICE
      where N_CONTRACT_ID =MyContractID
        and C_MIS_INVOICE_NUMBER =MyInvoiceNum;

     select count(*) into ctn
       from INVOICE_ITEM_WARNING_MSG
      where N_INVOICE_ID =MyInvoiceID
        and C_TYPE ='AUDIT';

    if ctn > 0 then

       update INVOICE_ITEM
          set F_WARNING_FLAG = 'N'
        where N_INVOICE_ID = MyInvoiceID;

       delete from INVOICE_ITEM_WARNING_MSG
       where N_INVOICE_ID = MyInvoiceID
         and C_TYPE ='AUDIT';

       commit;

       select count(*) into ctn
       from INVOICE_ITEM_WARNING_MSG
       where N_INVOICE_ID = MyInvoiceID
         and C_TYPE ='LOADING';

       if ctn > 0 then

        update INVOICE_ITEM
           set F_WARNING_FLAG = 'Y'
         where N_INVOICE_ITEM_ID in ( select distinct N_INVOICE_ITEM_ID
                                        from INVOICE_ITEM_WARNING_MSG
                                       where N_INVOICE_ID = MyInvoiceID
                                         and C_TYPE ='LOADING');
         commit;

       end if;

    end if;



     for c in (
                    select a.N_INVOICE_ID,
                           a.N_CONTRACT_ID,
                           a.N_INVOICE_YEAR_MONTH,
                           a.C_MIS_INVOICE_NUMBER,
                           b.N_INVOICE_ITEM_ID,
                           b.N_TASK_ORDER_BASE_ID,
                           b.C_SUB_TASK_ORDER_NAME,
                           b.N_SUB_TASK_ORDER_ID,
                           b.N_CONTRACTOR_ID,
                           b.N_EMPLOYEE_ID,
                           b.N_COST_TYPE_ID,
                           NVL(d.C_COST_TYPE_LABEL,'N/A') as C_COST_TYPE_LABEL,
                           b.N_QUANTITY,
                           b.N_COST,
                           b.N_G_AND_A,
                           b.N_FAA_COST,
                           b.C_DESCRIPTION,
                           b.N_ODC_TYPE_ID,
                           b.F_CORE,
                           b.C_ANI,
                           b.N_LABOR_CATEGORY_ID,
                           b.N_EXPERIENCE_ID,
                           b.N_ENTRY,
                           b.N_INVOICE_PERIOD_YEAR_MONTH,
                           b.N_INVOICE_ADJ_ID,
                           b.N_MIS_INVOICE_ITEM_ID,
                           DECODE( b.D_MIS_CHARGE_DATE, null, LAST_DAY(to_date(b.N_INVOICE_PERIOD_YEAR_MONTH,'YYYYMM')),b.D_MIS_CHARGE_DATE) as D_MIS_CHARGE_DATE
                    from INVOICE a, INVOICE_ITEM b, COST_TYPE d
                    where a.N_INVOICE_ID=b.N_INVOICE_ID
                      and a.N_CONTRACT_ID=MyContractID
                      and b.N_COST_TYPE_ID = d.N_COST_TYPE_ID (+)
                      and a.C_MIS_INVOICE_NUMBER =MyInvoiceNum) loop


         MySubTaskOrderStartDate :=null;
         MySubTaskOrderEndDate :=null;
         MyMaxHours:=0;
         MyHours:=0;

           -- Audit issue #1: Work period is later than bill period.

           if c.N_INVOICE_YEAR_MONTH < c.N_INVOICE_PERIOD_YEAR_MONTH then

                        MyProblemItem:='Work Period';
                        MyReason:='Work period '||c.N_INVOICE_PERIOD_YEAR_MONTH||' is later than bill period '||c.N_INVOICE_YEAR_MONTH||'.';
                        MyType:='AUDIT';

                        INVOICE_ITEM_AUDIT_MSG  ( c.N_INVOICE_ID, c.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);


           end if;


           -- Audit issue #2: Charges aged greater than 180 days
            if to_date(to_char(c.N_INVOICE_YEAR_MONTH),'YYYYMM')> ADD_MONTHS(to_date(to_char(c.N_INVOICE_PERIOD_YEAR_MONTH),'YYYYMM'),12) then

                        MyDays := to_date(to_char(c.N_INVOICE_YEAR_MONTH),'YYYYMM') - to_date(to_char(c.N_INVOICE_PERIOD_YEAR_MONTH),'YYYYMM');
                        MyProblemItem:='Charge Age';
                        MyReason:='Charge age ( '||to_char(MyDays)||' days ) is greater than 365 days.';
                        MyType:='AUDIT';

                        INVOICE_ITEM_AUDIT_MSG  ( c.N_INVOICE_ID, c.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);


          end if;

/*
	   --Commented on Aug 03, 2013 as per RTC#2541.
           -- Audit issue #3:  Charges outside of the period of performance of the subtask


            INVOICE_GET_SUBTO_DATES (c.N_SUB_TASK_ORDER_ID,MySubTaskOrderStartDate,MySubTaskOrderEndDate);

            if c.D_MIS_CHARGE_DATE < MySubTaskOrderStartDate or c.D_MIS_CHARGE_DATE > MySubTaskOrderEndDate then

                     select a.C_TASK_ORDER_NUMBER, b.C_SUB_TASK_ORDER_NAME
                     into MyTaskOrderNum,MySubTaskName
                     from task_order a, sub_task_order b
                     where a.N_TASK_ORDER_ID = b.N_TASK_ORDER_ID
                      and b.N_SUB_TASK_ORDER_ID = c.N_SUB_TASK_ORDER_ID;

                        MyProblemItem:='SubTaskOrder Start/End Dates';
                        MyReason:='The charge on '||to_char(c.D_MIS_CHARGE_DATE,'MM/DD/YYYY')||' is outside of the period of performance of the subtask order ('||MyTaskOrderNum||'-'||MySubTaskName||': '||to_char(MySubTaskOrderStartDate,'MM/DD/YYYY')||' - '||to_char(MySubTaskOrderEndDate,'MM/DD/YYYY')||').';
                        MyType:='AUDIT';

                        INVOICE_ITEM_AUDIT_MSG  ( c.N_INVOICE_ID, c.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);



           end if;

*/
          -- Audit issue #4:   Charges with no description
           if c.C_DESCRIPTION is null then

                        MyProblemItem:='None Description';
                        MyReason:='The charge is without description.';
                        MyType:='AUDIT';

                       INVOICE_ITEM_AUDIT_MSG  ( c.N_INVOICE_ID, c.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);



           end if;

          -- Audit issue #5:  Hours invoiced is over allowed

          if c.C_COST_TYPE_LABEL = 'Hours' and c.N_QUANTITY != 0 then -- Hours Cost Type

           INVOICE_GET_COMPANY_HOURS (c.N_CONTRACTOR_ID,c.N_INVOICE_PERIOD_YEAR_MONTH,MyMaxHours);

           INVOICE_GET_PAID_HOURS (c.N_CONTRACTOR_ID,c.N_EMPLOYEE_ID,c.N_INVOICE_PERIOD_YEAR_MONTH,c.N_INVOICE_ID,MyPaidHours) ;
           INVOICE_GET_PENDING_HOURS (c.N_CONTRACTOR_ID,c.N_EMPLOYEE_ID,c.N_INVOICE_PERIOD_YEAR_MONTH,c.N_INVOICE_ID,MyPendingHours) ;

           update INVOICE_ITEM
              set N_PAID_INVOICED_HOURS = NVL(MyPaidHours,0),
                  N_PENDING_INVOICE_HOURS =NVL(MyPendingHours,0),
                  N_MAX_ALLOWABLE_HOURS = NVL(MyMaxHours,0)
             where N_INVOICE_ITEM_ID = c.N_INVOICE_ITEM_ID;

            commit;

           MyHours := NVL(MyPaidHours,0) + NVL(MyPendingHours,0);

            If MyHours > MyMaxHours then

                        select C_CONTRACTOR_LABEL into MyCompanyName
                          from CONTRACTOR
                          where N_CONTRACTOR_ID = c.N_CONTRACTOR_ID;

                         if MyMaxHours = 0 then

                            MyMSG:='The maximum working hours for company '||MyCompanyName||' at month '||c.N_INVOICE_PERIOD_YEAR_MONTH||' is not available.';

                         else

                            MyMSG:='Hours ('||MyHours||') invoiced is over company ('||MyCompanyName||') allowed ( Max Hours '||MyMaxHours||' ).';

                         end if;

                        MyProblemItem:='Exceed Allowed Hours';
                        MyReason:=MyMSG;
                        MyType:='AUDIT';

                        INVOICE_ITEM_AUDIT_MSG  ( c.N_INVOICE_ID, c.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);


            end if;


          end if;

     end loop;


  -- Audit issue #6: Insufficient funds

     for c in (    select b.N_INVOICE_ID, b.N_TASK_ORDER_BASE_ID, b.C_SUB_TASK_ORDER_NAME, b.N_SUB_TASK_ORDER_ID, sum(b.N_FAA_COST) as InvoiveSubTOCost
                     from INVOICE a, INVOICE_ITEM b
                    where a.N_INVOICE_ID=b.N_INVOICE_ID
                      and a.N_CONTRACT_ID=MyContractID
                      and a.C_MIS_INVOICE_NUMBER =MyInvoiceNum
                 group by  b.N_INVOICE_ID,b.N_TASK_ORDER_BASE_ID, b.C_SUB_TASK_ORDER_NAME,b.N_SUB_TASK_ORDER_ID ) loop

                 SubTOAvailableFund := 0;

                INVOICE_GET_SUBTO_FUND (c.N_TASK_ORDER_BASE_ID, c.C_SUB_TASK_ORDER_NAME,c.N_INVOICE_ID, SubTOAvailableFund);


                 if  SubTOAvailableFund < 0 then

                    select a.C_TASK_ORDER_NUMBER, b.C_SUB_TASK_ORDER_NAME
                     into MyTaskOrderNum,MySubTaskName
                     from task_order a, sub_task_order b
                     where a.N_TASK_ORDER_ID = b.N_TASK_ORDER_ID
                      and b.N_SUB_TASK_ORDER_ID = c.N_SUB_TASK_ORDER_ID;


                    MyMSG:='Insufficient funds ('||to_char(SubTOAvailableFund)||') for this sub task order ('||MyTaskOrderNum||'-'||MySubTaskName ||').';
                    MyProblemItem:='Insufficient funds';
                    MyReason:=MyMSG;
                    MyType:='AUDIT';

                   for x in (
                             select m.N_INVOICE_ID,
                                    n.N_INVOICE_ITEM_ID
                               from INVOICE m, INVOICE_ITEM n
                              where m.N_INVOICE_ID=n.N_INVOICE_ID
                                and m.N_CONTRACT_ID=MyContractID
                                and m.C_MIS_INVOICE_NUMBER =MyInvoiceNum
                                and n.N_SUB_TASK_ORDER_ID = c.N_SUB_TASK_ORDER_ID ) loop


                        INVOICE_ITEM_AUDIT_MSG  ( x.N_INVOICE_ID, x.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);

                   end loop;


                 end if;

     end loop;

  -- Audit issue #7: Duplicate charges
     for p in (     select a.N_INVOICE_ID,
                           a.N_CONTRACT_ID,
                           a.N_INVOICE_YEAR_MONTH,
                           a.C_MIS_INVOICE_NUMBER,
                           b.N_SUB_TASK_ORDER_ID,
                           b.N_CONTRACTOR_ID,
                           b.N_EMPLOYEE_ID,
                           b.N_COST_TYPE_ID,
                           b.N_QUANTITY,
                           b.N_COST,
                           b.N_G_AND_A,
                           b.N_FAA_COST,
                           b.C_DESCRIPTION,
                           b.N_ODC_TYPE_ID,
                           b.F_CORE,
                           b.C_ANI,
                           b.N_LABOR_CATEGORY_ID,
                           b.N_EXPERIENCE_ID,
                           b.N_ENTRY,
                           b.N_INVOICE_PERIOD_YEAR_MONTH,
                           b.N_INVOICE_ADJ_ID,
                           count(*)
                    from INVOICE a, INVOICE_ITEM b
                    where a.N_INVOICE_ID=b.N_INVOICE_ID
                      and a.N_CONTRACT_ID=MyContractID
                      and a.C_MIS_INVOICE_NUMBER =MyInvoiceNum
                  group by a.N_INVOICE_ID,
                           a.N_CONTRACT_ID,
                           a.N_INVOICE_YEAR_MONTH,
                           a.C_MIS_INVOICE_NUMBER,
                           b.N_SUB_TASK_ORDER_ID,
                           b.N_CONTRACTOR_ID,
                           b.N_EMPLOYEE_ID,
                           b.N_COST_TYPE_ID,
                           b.N_QUANTITY,
                           b.N_COST,
                           b.N_G_AND_A,
                           b.N_FAA_COST,
                           b.C_DESCRIPTION,
                           b.N_ODC_TYPE_ID,
                           b.F_CORE,
                           b.C_ANI,
                           b.N_LABOR_CATEGORY_ID,
                           b.N_EXPERIENCE_ID,
                           b.N_ENTRY,
                           b.N_INVOICE_PERIOD_YEAR_MONTH,
                           b.N_INVOICE_ADJ_ID
                       having count(*) > 1) loop

                       DuplicateChargesItemIDStr := null;

                       for t in ( select  b.N_INVOICE_ITEM_ID
                                   from INVOICE a, INVOICE_ITEM b
                                  where a.N_INVOICE_ID=b.N_INVOICE_ID
                                    and a.N_INVOICE_ID = p.N_INVOICE_ID
                                    and a.N_CONTRACT_ID=p.N_CONTRACT_ID
                                    and a.N_INVOICE_YEAR_MONTH=p.N_INVOICE_YEAR_MONTH
                                    and a.C_MIS_INVOICE_NUMBER=p.C_MIS_INVOICE_NUMBER
                                    and b.N_SUB_TASK_ORDER_ID =p.N_SUB_TASK_ORDER_ID
                                    and b.N_CONTRACTOR_ID=p.N_CONTRACTOR_ID
                                    and NVL(b.N_EMPLOYEE_ID,0) =NVL(p.N_EMPLOYEE_ID,0)
                                    and b.N_COST_TYPE_ID =p.N_COST_TYPE_ID
                                    and b.N_QUANTITY =p.N_QUANTITY
                                    and b.N_COST =p.N_COST
                                    and b.N_G_AND_A =p.N_G_AND_A
                                    and b.N_FAA_COST =p.N_FAA_COST
                                    and NVL(b.C_DESCRIPTION,'N') = NVL(p.C_DESCRIPTION,'N')
                                    and NVL(b.N_ODC_TYPE_ID,0) =NVL(p.N_ODC_TYPE_ID,0)
                                    and NVL(b.F_CORE,'N') =NVL(p.F_CORE,'N')
                                    and NVL(b.C_ANI,'N')= NVL(p.C_ANI,'N')
                                    and NVL(b.N_LABOR_CATEGORY_ID,0) =NVL(p.N_LABOR_CATEGORY_ID,0)
                                    and NVL(b.N_EXPERIENCE_ID,0) =NVL(p.N_EXPERIENCE_ID,0)
                                    and b.N_ENTRY =p.N_ENTRY
                                    and b.N_INVOICE_PERIOD_YEAR_MONTH =p.N_INVOICE_PERIOD_YEAR_MONTH
                                    and b.N_INVOICE_ADJ_ID = p.N_INVOICE_ADJ_ID) loop

                             if DuplicateChargesItemIDStr is null then

                              DuplicateChargesItemIDStr:=t.N_INVOICE_ITEM_ID;

                             else

                              DuplicateChargesItemIDStr:=DuplicateChargesItemIDStr||', '||t.N_INVOICE_ITEM_ID;

                             end if;




                        end loop;

                      for t in ( select  b.N_INVOICE_ID,
                                         b.N_INVOICE_ITEM_ID
                                   from INVOICE a, INVOICE_ITEM b
                                  where a.N_INVOICE_ID=b.N_INVOICE_ID
                                    and a.N_INVOICE_ID = p.N_INVOICE_ID
                                    and a.N_CONTRACT_ID=p.N_CONTRACT_ID
                                    and a.N_INVOICE_YEAR_MONTH=p.N_INVOICE_YEAR_MONTH
                                    and a.C_MIS_INVOICE_NUMBER=p.C_MIS_INVOICE_NUMBER
                                    and b.N_SUB_TASK_ORDER_ID =p.N_SUB_TASK_ORDER_ID
                                    and b.N_CONTRACTOR_ID=p.N_CONTRACTOR_ID
                                    and NVL(b.N_EMPLOYEE_ID,0) =NVL(p.N_EMPLOYEE_ID,0)
                                    and b.N_COST_TYPE_ID =p.N_COST_TYPE_ID
                                    and b.N_QUANTITY =p.N_QUANTITY
                                    and b.N_COST =p.N_COST
                                    and b.N_G_AND_A =p.N_G_AND_A
                                    and b.N_FAA_COST =p.N_FAA_COST
                                    and NVL(b.C_DESCRIPTION,'N') = NVL(p.C_DESCRIPTION,'N')
                                    and NVL(b.N_ODC_TYPE_ID,0) =NVL(p.N_ODC_TYPE_ID,0)
                                    and NVL(b.F_CORE,'N') =NVL(p.F_CORE,'N')
                                    and NVL(b.C_ANI,'N')= NVL(p.C_ANI,'N')
                                    and NVL(b.N_LABOR_CATEGORY_ID,0) =NVL(p.N_LABOR_CATEGORY_ID,0)
                                    and NVL(b.N_EXPERIENCE_ID,0) =NVL(p.N_EXPERIENCE_ID,0)
                                    and b.N_ENTRY =p.N_ENTRY
                                    and b.N_INVOICE_PERIOD_YEAR_MONTH =p.N_INVOICE_PERIOD_YEAR_MONTH
                                    and b.N_INVOICE_ADJ_ID = p.N_INVOICE_ADJ_ID) loop


                             MyProblemItem:='Duplicate Charges';
                             MyReason:='Duplicate charges exist (invoice item ID:'||DuplicateChargesItemIDStr||').';
                             MyType:='AUDIT';

                             INVOICE_ITEM_AUDIT_MSG  ( t.N_INVOICE_ID, t.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);


                        end loop;




             end loop;





        -- Overridden Flag by NTP  on Sub task Order level  but it will not cover legacy NTPs which created on task order level
        /*
        select count(b.N_INVOICE_ITEM_ID) into ctn
           from INVOICE_ITEM_WARNING_MSG a,
                   INVOICE_ITEM b,
                   NTP_SUBTASK c,
                   NTP d
          where a.N_INVOICE_ID =MyInvoiceID
              and a.C_PROBLEM_ITEM ='Insufficient funds'
              and a.C_TYPE ='AUDIT'
              and a.N_INVOICE_ITEM_ID = b.N_INVOICE_ITEM_ID
              and b.N_TASK_ORDER_BASE_ID = c.N_TASK_ORDER_BASE_ID
              and  Upper(trim(B.C_SUB_TASK_ORDER_NAME)) =  Upper(trim(C.C_SUB_TASK_ORDER_NAME ))
              and c. N_NTP_ID=d.N_NTP_ID
              and d.N_OWNERSHIP_NUMBER in ( 204, 205);

         if ctn > 0 then

              update INVOICE_ITEM_WARNING_MSG
                 set F_OVERRIDE_FLAG = 'Y'
               where N_INVOICE_ID =MyInvoiceID
                 and C_PROBLEM_ITEM ='Insufficient funds'
                 and C_TYPE ='AUDIT'
                 and N_INVOICE_ITEM_ID in ( select distinct b.N_INVOICE_ITEM_ID
                                                             from INVOICE_ITEM_WARNING_MSG a,
                                                                     INVOICE_ITEM b,
                                                                     NTP_SUBTASK c,
                                                                     NTP d
                                                            where a.N_INVOICE_ID =MyInvoiceID
                                                               and a.C_PROBLEM_ITEM ='Insufficient funds'
                                                               and a.C_TYPE ='AUDIT'
                                                               and a.N_INVOICE_ITEM_ID = b.N_INVOICE_ITEM_ID
                                                               and b.N_TASK_ORDER_BASE_ID = c.N_TASK_ORDER_BASE_ID
                                                               and  Upper(trim(B.C_SUB_TASK_ORDER_NAME)) =  Upper(trim(C.C_SUB_TASK_ORDER_NAME ))
                                                               and c. N_NTP_ID=d.N_NTP_ID
                                                               and d.N_OWNERSHIP_NUMBER in ( 204, 205));
               commit;




         end if;

   */

  --  Overwritten Flag on task order level

  -- 03/16/2011 fix to ticket NISCIII-505
  -- If we execute the overwritten on task order level for both new sub task order NTP and legacy task order level NTP.
  -- It will work for legacy NTPs, but may overwitten more invoice items for the new NTP which is created on sub task order level
  -- But PMO Woody requested and  Sjawn approved  to overwritten flag on task order level for both new sub task order NTP and legacy task order level NTP.

         select count(b.N_INVOICE_ITEM_ID) into ctn
           from INVOICE_ITEM_WARNING_MSG a,
                   INVOICE_ITEM b,
                   TASK_ORDER c,
                   NTP d
          where a.N_INVOICE_ID =MyInvoiceID
            and a.C_PROBLEM_ITEM ='Insufficient funds'
            and a.C_TYPE ='AUDIT'
            and a.N_INVOICE_ITEM_ID = b.N_INVOICE_ITEM_ID
            and b.N_TASK_ORDER_BASE_ID = c.N_TASK_ORDER_BASE_ID
            and d.N_OBJECT_ID = c.N_TASK_ORDER_ID
            and d.N_OWNERSHIP_NUMBER in ( 204, 205);

         if ctn > 0 then

              update INVOICE_ITEM_WARNING_MSG
                 set F_OVERRIDE_FLAG = 'Y'
               where C_PROBLEM_ITEM ='Insufficient funds'
                 and C_TYPE ='AUDIT'
                 and N_INVOICE_ITEM_ID in ( select b.N_INVOICE_ITEM_ID
                                               from INVOICE_ITEM_WARNING_MSG a,
                                                       INVOICE_ITEM b,
                                                      TASK_ORDER c,
                                                       NTP d
                                           where a.N_INVOICE_ID =MyInvoiceID
                                              and a.C_PROBLEM_ITEM ='Insufficient funds'
                                              and a.C_TYPE ='AUDIT'
                                              and a.N_INVOICE_ITEM_ID = b.N_INVOICE_ITEM_ID
                                              and b.N_TASK_ORDER_BASE_ID = c.N_TASK_ORDER_BASE_ID
                                              and d.N_OBJECT_ID = c.N_TASK_ORDER_ID
                                              and d.N_OWNERSHIP_NUMBER in ( 204, 205));
              commit;




         end if;


         -- Update Warning flag in invoice_item table

         update INVOICE_ITEM
           set F_WARNING_FLAG = 'Y'
         where N_INVOICE_ITEM_ID in ( select distinct N_INVOICE_ITEM_ID
                                        from INVOICE_ITEM_WARNING_MSG
                                       where N_INVOICE_ID = MyInvoiceID
                                         and (F_OVERRIDE_FLAG is null or F_OVERRIDE_FLAG = 'N'));
         commit;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Rollback;
       RAISE;
END;




PROCEDURE   INVOICE_LOAD_DATA_FROM_MIS ( MyContrctNum number:=101,
                                         LoadStatus out varchar2)
IS
/******************************************************************************
   NAME:       LOAD_INVOICE_DATA_FROM_MIS (with audit table)
   PURPOSE:    This procedure will load the invoice data from MIS .
               Oracle job will run it once a day to check if the new invoice
               available or not. if it is available, then automatically load into
               invoice and invoice item tables.

             There are five loading status:

               1. New :                           it is the new invoice data, ready to load.

               2. Successfully:                   The data were loaded into invoice tables successfully.
                                                  And some data in the reference tables may have been updated.

               3. Successfully with warning :     The data were loaded into invoice tables successfully.
                                                  But some data with minor issue were loaded with flag and meeages.

               4. Failed:                         The data were failed to load into invoice tables.
                                                  Need to fix the problem and reload it again.

               5. Failed for reload :             The data were failed to reload
                                                  due to previous loaded data are good or already in process.

  Note:For special purpose:
        When an invoice has already loaded into invoice and invoice item tables. for some reason,
        really need to remove the exiting invoice data in invoice and invoice item table,

        Only the invoice whose status is rejected and no payment and letter created can be removed.

        There are three steps to process replacing:
         1) A/P rejecte this invoice.
         2) Run INVOICE_REMOVE first before or after run this procedure.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      08/02/2010  Chao Yu       1. Created this procedure.


******************************************************************************/

MyMISInvoiceNum number;
MyMISInvoiceItemID number;

MyKITTInvoiceID number;
MyKITTInvoiceStatus INVOICE.C_INVOICE_STATUS%type;
MyKITTYearMonth number;
MyKITTMISInvoiceNum varchar2(25);
MyKITTContractID number:=MyContrctNum;

MyInvoiceItemID number;
MySubTaskOrderID number;
MyTaskOrderBaseID  number;
MySubTaskOrderName varchar2(14);
MyEmployeeID number;
MyContractorID number;
MyCostTypeID number;
MyODCTypeID number;
MyLaborCateID number;
MyExperienceID number;

ctn number:=0;
Msg varchar2(4000);
Success number :=0;
Total number:=0;
MyUpdateDate date;
MyStatus number:=2;
SourceCount number;
LoadedCount number;
AuditCount number;
LoadStatusDesc varchar2(30);
MyLoadSeq number;

MAX_N_INVOICE_ID number;
SQLStr varchar2(200);
MyInvoiceDesc varchar2(150);

begin


   /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     Check the invoice data source provided by the vendor

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

 LoadStatus:= ' ';



 select count(distinct NISC_INV) into ctn  from V_MIS_INVOICE_DATA;

 if ctn = 1 then -- There is one invoice existing.

      select distinct NISC_INV into MyMISInvoiceNum  from V_MIS_INVOICE_DATA;

      MyKITTMISInvoiceNum:=to_char(MyMISInvoiceNum);

       select count(distinct NISC_INV) into ctn
         from V_MIS_INVOICE_DATA a, V_MIS_INVOICE_PULLING_STATUS b, V_MIS_INVOICE_PULLING_STATE c
        where a.NISC_INV = b.N_INVOICE_NUM
          and b.N_STATE_ID=c.N_STATE_ID
          and c.C_STATE_DESC ='New';

   if ctn = 1 then -- a new invoice is available.

      ctn:=0;

      INVOICE_GET_LOAD_SEQ_NUM (MyKITTContractID,MyKITTMISInvoiceNum,MyLoadSeq);

       -- Removed the rejected invoices
       for c in ( select N_INVOICE_ID, N_CONTRACT_ID, N_INVOICE_YEAR_MONTH,C_MIS_INVOICE_NUMBER
                    from INVOICE
                   where N_STATUS_NUMBER = -200 ) loop


              INVOICE_REMOVE ( c.N_CONTRACT_ID,
                               c.N_INVOICE_ID,
                               c.N_INVOICE_YEAR_MONTH,
                               Msg);

              if Msg is not null then

                 INVOICE_LOG_MSG_PARAM3(c.N_CONTRACT_ID,c.C_MIS_INVOICE_NUMBER,MyLoadSeq,Msg);

              end if;

       end loop;

      select count(*) into ctn from INVOICE where upper(trim(C_MIS_INVOICE_NUMBER)) = upper(trim(MyKITTMISInvoiceNum));

      if ctn > 0 then -- The invoice for this month already exist, it has been loaded before.

             -- Can not reload the invoice data again if the invoice already in Invoice and Invoice item tables.

            Msg:='Invoce for number '||MyKITTMISInvoiceNum||' has already loaded into Invoice table, can not reload it again.';
            INVOICE_LOG_MSG_PARAM3(MyKITTContractID,MyKITTMISInvoiceNum,MyLoadSeq,Msg);
            MyStatus:= 5; -- failed for reload.
            INVOICE_UPDATE_LOADING_STATUS(MyMISInvoiceNum,MyStatus);
            INVOICE_SEND_LOAD_STATUS_EMAIL (MyKITTContractID,MyKITTMISInvoiceNum,MyStatus);

            LoadStatus:= 'Invoice already loaded before. Can reload it after A/P rejected it.';
            return;


      else -- Clean up data in invoice_load_audit table and start loading data.

        delete from INVOICE_LOAD_AUDIT where C_MIS_INVOICE_NUMBER =MyKITTMISInvoiceNum;
        commit;

      end if;

   else

       select count(distinct NISC_INV) into ctn
         from V_MIS_INVOICE_DATA a, V_MIS_INVOICE_PULLING_STATUS b
        where a.NISC_INV = b.N_INVOICE_NUM
          and b.N_STATE_ID > 3;

       if ctn > 0 then  --MyStatus is 4 and 5

             select count(distinct NISC_INV) into ctn
              from V_MIS_INVOICE_DATA a, V_MIS_INVOICE_PULLING_STATUS b
             where a.NISC_INV = b.N_INVOICE_NUM
               and b.N_STATE_ID =4;

            if ctn > 0 then

                 MyStatus:=5;
                 Msg:='Invoce for number '||MyKITTMISInvoiceNum||' has been failed to load into Invoice table. '||
                      ' Check the log info, ask MIS fix it and re-submit invoice again before reload it.';

                 INVOICE_SEND_LOAD_STATUS_EMAIL (MyKITTContractID,MyKITTMISInvoiceNum,null, Msg);
                 INVOICE_UPDATE_LOADING_STATUS(MyKITTMISInvoiceNum,MyStatus);

            end if;

            LoadStatus:= 'Previous loading failed. Ask contractor re-submit previous invoice first.';
            return;

       else -- new invoice is not available yet. Do nothing. --MyStatus is 2 and 3

         LoadStatus:= 'No new invoice available';
         return;

       end if;




   end if;

 elsif ctn = 0 then -- No data was provided by MIS, Do nothing

     LoadStatus:= 'No new invoice available';
     return;

 else -- There are more one invoice in the invoice resource table.

     for p in ( select distinct a.NISC_INV,c.C_STATE_DESC
                  from V_MIS_INVOICE_DATA a, V_MIS_INVOICE_PULLING_STATUS b, V_MIS_INVOICE_PULLING_STATE c
                 where a.NISC_INV = b.N_INVOICE_NUM
                   and b.N_STATE_ID=c.N_STATE_ID) loop

          if p.C_STATE_DESC = 'New' then

              MyStatus := 4;
              INVOICE_GET_LOAD_SEQ_NUM (MyKITTContractID,to_char(p.NISC_INV),MyLoadSeq);

              Msg:='More than one month data were provided by MIS; Stop Loading Data.';
              INVOICE_LOG_MSG_PARAM3(MyKITTContractID,to_char(p.NISC_INV),MyLoadSeq,Msg);
              INVOICE_UPDATE_LOADING_STATUS(p.NISC_INV,MyStatus);
              INVOICE_SEND_LOAD_STATUS_EMAIL (MyKITTContractID,to_char(p.NISC_INV),MyStatus);

          end if;

     end loop;

     LoadStatus:= 'More than one new invoices available. Contractor can only submit one new invoice at one time.';
     return;

 end if;




    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     Insert Data into Invoice_load_audit table
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    if MyLoadSeq = 0 then
      -- Get next Load Sequence
       INVOICE_GET_LOAD_SEQ_NUM (MyKITTContractID,MyKITTMISInvoiceNum,MyLoadSeq);
    end if;

    Success :=0;
    Total :=0;

    INVOICE_UPDATE_CONTRACTOR;

    for c in ( select INVOICE_ID,PERIOD,PERIOD_ADJ,to_char(NISC_INV) as NISC_INV,N_INV_ADJ,
                      TO_NUMBER,SUB_TASK,COMPANY,NVL(NISC_NUM,0) as NISC_NUM, ENTRY,LAST_NAME,FIRST_NAME,
                      QTY,COST,G_AND_A,FAACOST,DESCR,CORE,ANI,
                      NVL(YRS_EXP,'N/A') as YRS_EXP,
                      NVL(KITT_LABOR_CATE_ID, 0 ) as KITT_LABOR_CATE_ID,KITT_LABOR_CATE,
                      NVL(KITT_ODC_TYPE_ID,0) as KITT_ODC_TYPE_ID,KITT_ODC_TYPE,
                      NVL(KITT_SUBTASK_ORDER_ID,0) as KITT_SUBTASK_ORDER_ID,
                      NVL(KITT_COST_TYPE_ID,0) as KITT_COST_TYPE_ID,KITT_COST_TYPE,
                      COMMENTS,
                      DECODE( CHARGE_DATE, null, LAST_DAY(to_date(PERIOD_ADJ,'YYYYMM')),CHARGE_DATE) as CHARGE_DATE,
                      NVL(NISC_INV_DESC,'') as NISC_INV_DESC, KITT_TO_BASE_ID ,KITT_SUBTO_NAME
                      from V_MIS_INVOICE_DATA
                      where NISC_INV= MyMISInvoiceNum )loop

      begin


          --Validate to sure no company info missing
          INVOICE_VERIFY_COMPANY(
                                  MyKITTContractID,
                                  c.NISC_INV,
                                  MyLoadSeq,
                                  c.INVOICE_ID,
                                  c.COMPANY,
                                  MyStatus);

         --Validate company info and return ContractorID and Loading status
          INVOICE_GET_COMPANY_ID ( MyKITTContractID,
                                   c.NISC_INV,
                                   MyLoadSeq,
                                   c.INVOICE_ID,
                                   c.COMPANY,
                                   MyContractorID,
                                   MyStatus);

         -- Validate to sure no employee, ODC type, Labor category and Years experienc information missing
         INVOICE_VERIFY_EMPLOYEE_ODC (
                                        MyKITTContractID,
                                        c.NISC_INV,
                                        MyLoadSeq,
                                        c.INVOICE_ID,
                                        c.LAST_NAME,
                                        c.KITT_ODC_TYPE_ID,
                                        c.NISC_NUM,
                                        c.ENTRY,
                                        c.KITT_LABOR_CATE_ID,
                                        c.YRS_EXP,
                                        c.KITT_COST_TYPE_ID,
                                        MyStatus );


         -- Validate Employee info and return EmployeeID and Loading status
          INVOICE_GET_EMPLOYEE_ID ( MyKITTContractID,
                                    c.NISC_INV,
                                    MyLoadSeq,
                                    c.INVOICE_ID,
                                    MyContractorID,
                                    c.NISC_NUM,
                                    c.LAST_NAME,
                                    c.FIRST_NAME,
                                    MyEmployeeID,
                                    MyStatus);

          -- Validate cost type id and return Loading status
           MyCostTypeID:= c.KITT_COST_TYPE_ID;
           INVOICE_VERIFY_COST_TYPE_ID (MyKITTContractID,
                                        c.NISC_INV,
                                        MyLoadSeq,
                                        c.INVOICE_ID,
                                        MyCostTypeID,
                                        MyStatus);

          -- Validate Experience info and return Experience id and Loading status
        /*
         INVOICE_GET_EXPERIENCE_ID (MyKITTContractID,
                                     c.NISC_INV,
                                     MyLoadSeq,
                                     c.INVOICE_ID,
                                     c.YRS_EXP,
                                     MyExperienceID,
                                     MyStatus);

       */

           MyExperienceID:= null;
          -- Validate Labor Catetory info and return Labor Catetory id and Loading status
          MyLaborCateID:= c.KITT_LABOR_CATE_ID;
          INVOICE_VERIFY_LABOR_CATE_ID (MyKITTContractID,
                                        c.NISC_INV,
                                        MyLoadSeq,
                                        c.INVOICE_ID,
                                        c.KITT_LABOR_CATE,
                                        MyLaborCateID,
                                        MyStatus);


          -- Validate ODC Type info and return ODC Type id and Loading status
          MyODCTypeID:=c.KITT_ODC_TYPE_ID;
          INVOICE_VERIFY_ODC_TYPE_ID (MyKITTContractID,
                                      c.NISC_INV,
                                      MyLoadSeq,
                                      c.INVOICE_ID,
                                      c.KITT_ODC_TYPE,
                                      MyODCTypeID,
                                      MyStatus);

          MySubTaskOrderID:=c.KITT_SUBTASK_ORDER_ID;
          MyTaskOrderBaseID:=c.KITT_TO_BASE_ID;
          MySubTaskOrderName :=c.KITT_SUBTO_NAME;

          INVOICE_VERIFY_SUB_TO_ID (  MyKITTContractID,
                                      c.NISC_INV,
                                      MyLoadSeq,
                                      c.INVOICE_ID,
                                      MySubTaskOrderID,
                                      MyTaskOrderBaseID,
                                      MySubTaskOrderName,
                                      MyStatus);

          Insert into INVOICE_LOAD_AUDIT(
                  N_MIS_INVOICE_ITEM_ID,
                  N_INVOICE_YEAR_MONTH,N_INVOICE_PERIOD_YEAR_MONTH,
                  N_INVOICE_ADJ_ID,C_MIS_INVOICE_NUMBER,
                  D_INVOICE_LOAD_DATE, C_INVOICE_STATUS,
                  N_CONTRACT_ID,
                  N_TASK_ORDER_BASE_ID,C_SUB_TASK_ORDER_NAME, N_SUB_TASK_ORDER_ID,
                  TO_NUMBER,SUB_TASK,
                  N_EMPLOYEE_ID,NISC_NUM,
                  N_ENTRY,
                  LAST_NAME,FIRST_NAME,
                  N_CONTRACTOR_ID,COMPANY,
                  N_LABOR_CATEGORY_ID, LABOR_CATEGORY,
                  N_EXPERIENCE_ID,YRS_EXP,
                  N_COST_TYPE_ID,COST_TYPE,
                  N_QUANTITY, N_COST,
                  N_G_AND_A,N_FAA_COST,
                  C_DESCRIPTION,
                  N_ODC_TYPE_ID, ODC_TYPE,
                  F_CORE, C_ANI,
                  T_MIS_COMMENTS,D_MIS_CHARGE_DATE,C_INVOICE_DESC)

           Values(
                  c.INVOICE_ID,
                  c.PERIOD,c.PERIOD_ADJ,
                  c.N_INV_ADJ,c.NISC_INV,
                  sysdate,'NEW',
                  MyKITTContractID,
                  MyTaskOrderBaseID,MySubTaskOrderName,MySubTaskOrderID,
                  c.TO_NUMBER,c.SUB_TASK,
                  MyEmployeeID, c.NISC_NUM,
                  c.ENTRY,
                  c.LAST_NAME,c.FIRST_NAME,
                  MyContractorID, c.COMPANY,
                  MyLaborCateID,c.KITT_LABOR_CATE,
                  MyExperienceID,c.YRS_EXP,
                  MyCostTypeID, c.KITT_COST_TYPE,
                  c.QTY,c.COST,
                  c.G_AND_A,c.FAACOST,
                  c.DESCR,
                  MyODCTypeID, c.KITT_ODC_TYPE,
                  c.CORE, c.ANI,c.COMMENTS,c.CHARGE_DATE,c.NISC_INV_DESC );

          commit;
          Success :=Success +1;

      EXCEPTION
        WHEN OTHERS THEN
           Rollback;
           Msg:='Error:Got exception during insert record:'||to_char(SQLCODE) ||'-'||SQLERRM;
           INVOICE_LOG_MULTI_PARAM (
                                       MyKITTContractID,
                                       c.NISC_INV,
                                       MyLoadSeq,
                                       c.INVOICE_ID,
                                       'Insert Record Row',
                                       'MIS Invoice ID:' ||c.INVOICE_ID,
                                       'Failed',
                                        Msg);
            commit;

            MyStatus:= 4; -- failed
            INVOICE_UPDATE_LOADING_STATUS(c.NISC_INV,MyStatus);
      end;

      Total:=Total+1;

   end loop;

   commit;


   Msg:='The invoice data for invoice num '||MyKITTMISInvoiceNum||' ('||Success||'/'||Total||') have been loaded into invoice_load_audit table.';
   INVOICE_LOG_MSG_PARAM3(MyKITTContractID,MyKITTMISInvoiceNum,MyLoadSeq,Msg);

   -- Get total number of entries avaialbe from invoice source.
   select count(*) into SourceCount from V_MIS_INVOICE_DATA where NISC_INV = MyMISInvoiceNum;

   -- Get total number of entries avaialbe from invoice source.
   select count(*) into AuditCount from INVOICE_LOAD_AUDIT where C_MIS_INVOICE_NUMBER = MyKITTMISInvoiceNum;

   if (SourceCount=AuditCount) and MyStatus < 4 then

     BEGIN

     /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        Set up warning indicator in INVOICE_LOAD_AUDIT table
        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

        if MyStatus = 3 then

           for t in ( select distinct N_MIS_INVOICE_ITEM_ID
                        from INVOICE_LOAD_LOG
                       where upper(N_LOADED_DATA)='WARNING'
                         and N_LOAD_SEQ = MyLoadSeq
                         and N_CONTRACT_ID = MyKITTContractID
                         and C_INVOICE_NUM =MyKITTMISInvoiceNum) loop

                      update INVOICE_LOAD_AUDIT
                        set F_WARNING_FLAG ='Y'
                      where N_CONTRACT_ID = MyKITTContractID
                        and N_MIS_INVOICE_ITEM_ID = t.N_MIS_INVOICE_ITEM_ID
                        and C_MIS_INVOICE_NUMBER = MyKITTMISInvoiceNum;


            end loop;

            commit;

        end if;

     /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        Insert Data into Invoice Table
     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

      MyKITTInvoiceID := 0;

      -- Get the next invoive ID from sequence
      select SEQ_INVOICE.nextval into MyKITTInvoiceID from dual;

      select distinct PERIOD,to_char(NISC_INV),NVL(NISC_INV_DESC,'') into MyKITTYearMonth,MyKITTMISInvoiceNum,MyInvoiceDesc
        from V_MIS_INVOICE_DATA;

      Insert into INVOICE (
                   N_INVOICE_ID,
                   N_INVOICE_YEAR_MONTH,
                   C_MIS_INVOICE_NUMBER,
                   D_INVOICE_RECEIVED_DATE,
                   C_INVOICE_STATUS,
                   N_STATUS_NUMBER,
                   N_CONTRACT_ID,
                   C_INVOICE_DESC)
             Values(
                   MyKITTInvoiceID,
                   MyKITTYearMonth,
                   MyKITTMISInvoiceNum,
                   sysdate,
                   'NEW',
                    300,
                   MyKITTContractID,
                   MyInvoiceDesc);



      /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
       Insert Data into Invoice Item Table
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

      for c in ( select N_MIS_INVOICE_ITEM_ID,N_INVOICE_PERIOD_YEAR_MONTH,N_INVOICE_ADJ_ID,
                        N_TASK_ORDER_BASE_ID,C_SUB_TASK_ORDER_NAME,N_SUB_TASK_ORDER_ID,N_EMPLOYEE_ID,NISC_NUM,N_ENTRY,
                        N_CONTRACTOR_ID,N_LABOR_CATEGORY_ID,
                        N_EXPERIENCE_ID,N_COST_TYPE_ID,
                        N_QUANTITY,N_COST,N_G_AND_A,N_FAA_COST,C_DESCRIPTION,N_ODC_TYPE_ID,NVL(F_CORE,'N') as F_CORE ,C_ANI,
                        NVL(F_WARNING_FLAG, 'N') as F_WARNING_FLAG,T_MIS_COMMENTS,D_MIS_CHARGE_DATE
                   from INVOICE_LOAD_AUDIT
                   where C_MIS_INVOICE_NUMBER =MyKITTMISInvoiceNum
                     and N_CONTRACT_ID = MyKITTContractID) loop

             -- Get the next invoive item ID from sequence
             select SEQ_INVOICE_ITEM.nextval into MyInvoiceItemID from dual;

             insert into INVOICE_ITEM (
                      N_INVOICE_ITEM_ID,
                      N_INVOICE_ID,
                      N_INVOICE_PERIOD_YEAR_MONTH,
                      N_INVOICE_ADJ_ID,
                      N_TASK_ORDER_BASE_ID,
                      C_SUB_TASK_ORDER_NAME,
                      N_SUB_TASK_ORDER_ID,
                      N_EMPLOYEE_ID,
                      N_COST_TYPE_ID,
                      N_QUANTITY,
                      N_COST,
                      N_G_AND_A,
                      N_FAA_COST,
                      C_DESCRIPTION,
                      N_ODC_TYPE_ID,
                      F_CORE,
                      C_ANI,
                      N_LABOR_CATEGORY_ID,
                      N_EXPERIENCE_ID,
                      N_ENTRY,
                      N_MIS_INVOICE_ITEM_ID,
                      N_CONTRACTOR_ID,
                      F_WARNING_FLAG,
                      T_MIS_COMMENTS,
                      D_MIS_CHARGE_DATE)
              Values (
                       MyInvoiceItemID,
                       MyKITTInvoiceID,
                       c.N_INVOICE_PERIOD_YEAR_MONTH,
                       c.N_INVOICE_ADJ_ID,
                       c.N_TASK_ORDER_BASE_ID,
                       c.C_SUB_TASK_ORDER_NAME,
                       c.N_SUB_TASK_ORDER_ID,
                       c.N_EMPLOYEE_ID,
                       c.N_COST_TYPE_ID,
                       c.N_QUANTITY,
                       c.N_COST,
                       c.N_G_AND_A,
                       c.N_FAA_COST,
                       c.C_DESCRIPTION,
                       c.N_ODC_TYPE_ID,
                       c.F_CORE,
                       c.C_ANI,
                       c.N_LABOR_CATEGORY_ID,
                       c.N_EXPERIENCE_ID,
                       c.N_ENTRY,
                       c.N_MIS_INVOICE_ITEM_ID,
                       c.N_CONTRACTOR_ID,
                       c.F_WARNING_FLAG,
                       c.T_MIS_COMMENTS,
                       c.D_MIS_CHARGE_DATE
                     );


                 if c.F_WARNING_FLAG = 'Y' then

                    for p in (select C_PROBLEM_ITEM,C_REASON
                                from INVOICE_LOAD_LOG
                               where upper(N_LOADED_DATA)='WARNING'
                                 and N_LOAD_SEQ = MyLoadSeq
                                 and N_CONTRACT_ID = MyKITTContractID
                                 and C_INVOICE_NUM =MyKITTMISInvoiceNum
                                 and N_MIS_INVOICE_ITEM_ID = c.N_MIS_INVOICE_ITEM_ID
                            order by C_PROBLEM_ITEM) loop

                         insert into INVOICE_ITEM_WARNING_MSG
                           (
                             N_INVOICE_ID,
                             N_INVOICE_ITEM_ID,
                             C_PROBLEM_ITEM,
                             C_REASON,
                             C_TYPE,
                             D_AUDIT_DATE
                           )
                        values
                           (
                             MyKITTInvoiceID,
                             MyInvoiceItemID,
                             p.C_PROBLEM_ITEM,
                             p.C_REASON,
                             'LOADING',
                             sysdate
                           );

                    end loop;

                 end if;




      end loop;
      commit;

        -- get toatl number of entries loaded into invoice and invoice item tables.
      select count(*) into LoadedCount
        from INVOICE a, INVOICE_ITEM b
       where a.N_INVOICE_ID = b.N_INVOICE_ID
         and a.C_MIS_INVOICE_NUMBER = MyKITTMISInvoiceNum;

      if SourceCount = LoadedCount then

        select lower(C_STATE_DESC) into LoadStatusDesc
          from V_MIS_INVOICE_PULLING_STATE
         where  N_STATE_ID = MyStatus;

         Msg:='The invoice records '||LoadedCount||' in total for invoice num '||MyKITTMISInvoiceNum||' have been loaded into invoice and invoice item table '||LoadStatusDesc||'.';

      else

        delete from INVOICE_ITEM_WARNING_MSG where N_INVOICE_ID = MyKITTInvoiceID;
        delete from INVOICE_ITEM where N_INVOICE_ID = MyKITTInvoiceID;
        delete from INVOICE  where N_INVOICE_ID = MyKITTInvoiceID;
        commit;
        MyStatus:=4;
        Msg:='The invoice data for invoice number '||MyKITTMISInvoiceNum||' have been failed to load into invoice item table from audit table. Need to fix the probelm and reload it again.';

      end if;

      INVOICE_LOG_MSG_PARAM3(MyKITTContractID,MyKITTMISInvoiceNum,MyLoadSeq,Msg);
      INVOICE_UPDATE_LOADING_STATUS(MyMISInvoiceNum,MyStatus);

      Begin

         INVOICE_ITEM_AUDIT (MyKITTContractID, MyKITTMISInvoiceNum);
         INVOICE_LOG_MSG_PARAM3(MyKITTContractID,MyKITTMISInvoiceNum,MyLoadSeq,'Invoice item audit has been completed.');

      EXCEPTION

       WHEN OTHERS THEN

       Msg:='Invoice item audit has been failed. Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyKITTContractID,
                                       MyKITTMISInvoiceNum,
                                       MyLoadSeq,
                                       null,
                                       'Audit',
                                       null,
                                       'Failed',
                                       Msg);

         INVOICE_SEND_SUPPORT_EMAIL (
                                          MyKITTContractID,
                                          MyKITTMISInvoiceNum,
                                          'INVOICE AUDIT',
                                           Msg);

          MyStatus:= 7; -- Loading sccessfully, but audit failed


       END;


    EXCEPTION

       WHEN OTHERS THEN
       Rollback;
       Msg:='Rollback:Failed to load data into invoice or invoice item tables. Check the data in the audit table. Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyKITTContractID,
                                       MyKITTMISInvoiceNum,
                                       MyLoadSeq,
                                       null,
                                       'Loading to Invoice/InvoiceItem',
                                       null,
                                       'Failed',
                                       Msg);

       MyStatus:= 4; -- failed
       INVOICE_UPDATE_LOADING_STATUS(MyMISInvoiceNum,MyStatus);
    END;

   else

        Msg:='The invoce data for invoice num '||MyKITTMISInvoiceNum||' can not be loaded into invoice table. Need to fix the probelm and reload it again.';


     INVOICE_LOG_MSG_PARAM3(MyKITTContractID,MyKITTMISInvoiceNum,MyLoadSeq,Msg);
     INVOICE_UPDATE_LOADING_STATUS(MyMISInvoiceNum,MyStatus);


   end if;

   Commit;
   INVOICE_SEND_LOAD_STATUS_EMAIL (MyKITTContractID,MyKITTMISInvoiceNum,MyStatus);

   if MyStatus > 3 then

       LoadStatus:= 'Invoice loading or auditing failed. Please check invoice loading log table.';

   else

       LoadStatus:= 'Invoice loaded successfully.';

   end if;

EXCEPTION

   WHEN OTHERS THEN
       Rollback;
       Msg:='Error:Got exception when run loading procedure:'||to_char(SQLCODE) ||'-'||SQLERRM||'.';
       INVOICE_LOG_MULTI_PARAM (
                                       MyKITTContractID,
                                       MyKITTMISInvoiceNum,
                                       MyLoadSeq,
                                       null,
                                       'Loading process',
                                       null,
                                       'Failed',
                                       Msg);

       MyStatus:= 4; -- failed
       INVOICE_UPDATE_LOADING_STATUS(MyMISInvoiceNum,MyStatus);
       INVOICE_SEND_LOAD_STATUS_EMAIL (MyKITTContractID,MyKITTMISInvoiceNum,MyStatus);
       LoadStatus:= 'Invoice loading failed. Ask contractor submit invoice with fixed data again.';

end;


PROCEDURE     INVOICE_LOAD_BATCH
IS

/******************************************************************************
   NAME:       INVOICE_LOAD_BATCH
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/3/2010  Chao Yu       1. Created this procedure.

   NOTES:


******************************************************************************/

LoadStatus varchar2(200);

BEGIN


   INVOICE_LOAD_DATA_FROM_MIS (101,LoadStatus );

   insert into SCHEDULED_TASK_LOG (N_SCHEDULE_TASK_LOG_ID,C_ACTION_LABEL,D_TASK_DATE,C_DESCRIPTION)
   values (SEQ_SCHEDULED_TASK_LOG.nextval, 'Load Invoice', sysdate,LoadStatus);
   commit;


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
      ROLLBACK;

END INVOICE_LOAD_BATCH;



PROCEDURE      INVOICE_LOAD_BATCH_15MIN
IS

/******************************************************************************
   NAME:       INVOICE_LOAD_BATCH
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        7/20/2009   Chao Yu       1. Created this procedure.

   NOTES:


******************************************************************************/

LoadStatus varchar2(200);

BEGIN


   INVOICE_LOAD_DATA_FROM_MIS (101,LoadStatus );

   if ( LoadStatus <>'No new invoice available') then

      insert into SCHEDULED_TASK_LOG (N_SCHEDULE_TASK_LOG_ID,C_ACTION_LABEL,D_TASK_DATE,C_DESCRIPTION)
           values (SEQ_SCHEDULED_TASK_LOG.nextval, 'Load Invoice', sysdate,LoadStatus);
           commit;
   end if;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
      ROLLBACK;
END ;




END PK_INVOICE_LOADING;
/
