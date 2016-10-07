DROP PROCEDURE SP_INVOICE_LOADING_AUDITS;

CREATE OR REPLACE PROCEDURE              "SP_INVOICE_LOADING_AUDITS" AS 
 INVOICE_YEAR_MONTH number;
 CostTypelable varchar2(25);
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

 cursor c1 is
    SELECT N_INVOICE_ITEM_ID,N_INVOICE_ID,N_TASK_ORDER_BASE_ID,C_SUB_TASK_ORDER_NAME,N_SUB_TASK_ORDER_ID,N_CONTRACTOR_ID,
  N_EMPLOYEE_ID,N_COST_TYPE_ID,N_QUANTITY,N_COST,N_G_AND_A,N_FAA_COST,C_DESCRIPTION,N_ODC_TYPE_ID,F_CORE,C_ANI,N_LABOR_CATEGORY_ID,
  N_EXPERIENCE_ID,N_ENTRY,T_ETO_COMMENTS,T_PMO_COMMENTS,F_ETO_DISPUTE_FLAG,F_PMO_DISPUTE_FLAG,N_INVOICE_PERIOD_YEAR_MONTH,
  N_INVOICE_ADJ_ID,N_MIS_INVOICE_ITEM_ID,N_ETO_REJECT_REASON_ID,N_PMO_REJECT_REASON_ID,T_ETO_REJECT_REASON,T_PMO_REJECT_REASON,
  T_ETO_OTHER_REJECT_REASON,T_PMO_OTHER_REJECT_REASON,F_WARNING_FLAG,T_MIS_COMMENTS,D_MIS_CHARGE_DATE,N_PAID_INVOICED_HOURS,
  N_PENDING_INVOICE_HOURS,N_MAX_ALLOWABLE_HOURS,F_ETO_CERT_FLAG,N_CERT_ETO_ID,D_ETO_CERT_TS,F_ETO_REVIEW_FLAG,N_REVIEW_ETO_ID,
  D_ETO_REVIEW_TS,F_PMO_REVIEW_FLAG,N_REVIEW_PMO_ID,D_PMO_REVIEW_TS FROM Kitt_nisc3.INVOICE_ITEM
  WHERE n_invoice_id =(select Max(N_Invoice_ID) from KITT_NISC3.Invoice);
  
  rec Kitt_nisc3.invoice_Item%rowtype;
BEGIN
 
 FOR rec in c1
   LOOP
              -- Audit issue #1: Work period is later than bill period.
                  select N_INVOICE_YEAR_MONTH into INVOICE_YEAR_MONTH  from Kitt_nisc3.Invoice where Kitt_nisc3.Invoice.N_Invoice_ID = rec.N_Invoice_ID;
                  
                   if INVOICE_YEAR_MONTH < rec.N_INVOICE_PERIOD_YEAR_MONTH then
                                MyProblemItem:='Work Period';
                                MyReason:='Work period '||rec.N_INVOICE_PERIOD_YEAR_MONTH||' is later than bill period '||INVOICE_YEAR_MONTH||'.';
                                MyType:='AUDIT';
                                INVOICE_ITEM_AUDIT_MSG  (rec.N_Invoice_ID, rec.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);
                   end if;
        
        -- Audit issue #2: Charges aged greater than 180 days
                    if to_date(to_char(INVOICE_YEAR_MONTH),'YYYYMM')> ADD_MONTHS(to_date(to_char(rec.N_INVOICE_PERIOD_YEAR_MONTH),'YYYYMM'),12) then
                                MyDays := to_date(to_char(INVOICE_YEAR_MONTH),'YYYYMM') - to_date(to_char(rec.N_INVOICE_PERIOD_YEAR_MONTH),'YYYYMM');
                                MyProblemItem:='Charge Age';
                                MyReason:='Charge age ( '||to_char(MyDays)||' days ) is greater than 365 days.';
                                MyType:='AUDIT';
                                INVOICE_ITEM_AUDIT_MSG  (rec.N_Invoice_ID, rec.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);
                  end if;
                  
                  /*
                    --Commented on Aug 03, 2013 as per RTC#2541.
        -- Audit issue #3:  Charges outside of the period of performance of the subtask
                */
                
        -- Audit issue #4:   Charges with no description
                   if rec.C_DESCRIPTION is null then
                                MyProblemItem:='None Description';
                                MyReason:='The charge is without description.';
                                MyType:='AUDIT';
                               INVOICE_ITEM_AUDIT_MSG  ( rec.N_INVOICE_ID, rec.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);
                   end if;
                   
-- Audit issue #5:  Hours invoiced is over allowed
          select NVL(d.C_COST_TYPE_LABEL,'N/A') into CostTypelable
             from KITT_NISC3.COST_TYPE d  where rec.N_COST_TYPE_ID = d.N_COST_TYPE_ID;
          if CostTypelable = 'Hours' and rec.N_QUANTITY != 0 then -- Hours Cost Type

           INVOICE_GET_COMPANY_HOURS (rec.N_CONTRACTOR_ID,rec.N_INVOICE_PERIOD_YEAR_MONTH,MyMaxHours);
           INVOICE_GET_PAID_HOURS (rec.N_CONTRACTOR_ID,rec.N_EMPLOYEE_ID,rec.N_INVOICE_PERIOD_YEAR_MONTH,rec.N_INVOICE_ID,MyPaidHours) ;
           INVOICE_GET_PENDING_HOURS (rec.N_CONTRACTOR_ID,rec.N_EMPLOYEE_ID,rec.N_INVOICE_PERIOD_YEAR_MONTH,rec.N_INVOICE_ID,MyPendingHours) ;

            update KITT_NISC3.invoice_item
              set N_PAID_INVOICED_HOURS = NVL(MyPaidHours,0),
                  N_PENDING_INVOICE_HOURS =NVL(MyPendingHours,0),
                  N_MAX_ALLOWABLE_HOURS = NVL(MyMaxHours,0)
             where N_INVOICE_ITEM_ID = rec.N_INVOICE_ITEM_ID;

            MyHours := NVL(MyPaidHours,0) + NVL(MyPendingHours,0);

            If MyHours > MyMaxHours then
                        select C_CONTRACTOR_LABEL into MyCompanyName
                          from KITT_NISC3.CONTRACTOR
                          where N_CONTRACTOR_ID = rec.N_CONTRACTOR_ID;
                         if MyMaxHours = 0 then
                            MyMSG:='The maximum working hours for company '||MyCompanyName||' at month '||rec.N_INVOICE_PERIOD_YEAR_MONTH||' is not available.';
                         else
                            MyMSG:='Hours ('||MyHours||') invoiced is over company ('||MyCompanyName||') allowed ( Max Hours '||MyMaxHours||' ).';
                         end if;
                        MyProblemItem:='Exceed Allowed Hours';
                        MyReason:=MyMSG;
                        MyType:='AUDIT';
                        INVOICE_ITEM_AUDIT_MSG  (rec.N_INVOICE_ID, rec.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);
            end if;
          end if;
        
      -- Audit issue #6: Insufficient funds
      -- commented out as there are no valid subtaskorders id's, will uncomment when K2K3 TO mappings are complete 
         /* SubTOAvailableFund := 0;
          INVOICE_GET_SUBTO_FUND (rec.N_TASK_ORDER_BASE_ID, rec.C_SUB_TASK_ORDER_NAME,rec.N_INVOICE_ID, SubTOAvailableFund);
          if  SubTOAvailableFund < 0 then
              select a.C_TASK_ORDER_NUMBER, b.C_SUB_TASK_ORDER_NAME
               into MyTaskOrderNum,MySubTaskName
               from KITT_NISC3.task_order a, KITT_NISC3.sub_task_order b
               where a.N_TASK_ORDER_ID = b.N_TASK_ORDER_ID
                and b.N_SUB_TASK_ORDER_ID = rec.N_SUB_TASK_ORDER_ID;
              MyMSG:='Insufficient funds ('||to_char(SubTOAvailableFund)||') for this sub task order ('||MyTaskOrderNum||'-'||MySubTaskName ||').';
              MyProblemItem:='Insufficient funds';
              MyReason:=MyMSG;
              MyType:='AUDIT';

              INVOICE_ITEM_AUDIT_MSG  ( rec.N_INVOICE_ID, rec.N_INVOICE_ITEM_ID,MyProblemItem,MyReason,MyType);
           end if; */
                   
        -- Audit issue #7: Duplicate charges
             -- Discuss IMplementation
   END LOOP;
END SP_INVOICE_LOADING_AUDITS;
/
