DROP PROCEDURE "SP_NAT_INVOICE_LOAD_orig";

CREATE OR REPLACE PROCEDURE            "SP_NAT_INVOICE_LOAD_orig" (InvoiceID number) AS 
 NewInvoiceID number;
 InvoiceStatus number;
BEGIN
NewInvoiceID :=InvoiceID;

-- Insert Header for Invoice KITT2
  insert into KITT_NISC3.Invoice (n_invoice_id
  ,n_Contract_ID
,n_Invoice_Year_month
,C_MIS_INVOICE_NUMBER
,D_INVOICE_RECEIVED_DATE
,C_INVOICE_STATUS
,N_STATUS_NUMBER
,C_INVOICE_DESC)
values(NewInvoiceID
,101
,(select INVOICE_PERIOD from NAT_INVOICE_HEADER where INVOICE_NUMBER=NewInvoiceID)
,NewInvoiceID
,current_date
,'New'
,300
, (select DESCRIPTION from NAT_INVOICE_HEADER where INVOICE_NUMBER=NewInvoiceID));

-- Get Max ID for Invoice
--select Max(N_Invoice_ID) into NewInvoiceID from KITT_NISC3.Invoice;

--Populate INvoice Item in KITT2
insert into KITT_NISC3.Invoice_Item (
                          N_INVOICE_ID
                          ,n_invoice_item_id
                          ,n_Task_Order_Base_ID
                          ,C_SUb_Task_order_Name
                          ,n_Sub_Task_Order_ID
                          ,n_contractor_ID
                          ,n_Employee_ID
                          ,n_Cost_Type_ID
                          ,n_Quantity
                          ,n_Cost
                          ,n_FAA_Cost
                          ,c_Description
                          ,n_ODC_Type_ID
                          ,n_Labor_Category_ID
                          ,n_Invoice_Adj_ID
                          ,D_MIS_Charge_Date
                          ,N_MIS_INVOICE_ITEM_ID
                          ,N_G_and_A
                          ,f_core
                          ,N_INVOICE_PERIOD_YEAR_MONTH)
SELECT 
                          NewInvoiceID
                          ,(KITT_NISC3.seq_invoice_item.nextval)
                          ,nvl(J.KH_N_Task_Order_Base_ID,A.taskorder) --Modified 04/07/2014 --A.BASE_TASK_ORDER_NUMBER
                          ,'Subtask ' || A.SUBTASK
                         ,nvl((SELECT max(z.KH_N_SUBTASK_ORDER_ID) FROM KITT_NISC3.SUB_TASK_ORDER_MAP z where z.KH_N_Task_Order_Base_ID = J.KH_N_Task_Order_Base_ID and upper(trim(A.SUBTASK)) = upper(trim(z.k3_SUB_TASK_ORDER_NUMBER))),1)
                          --,nvl(G.KH_N_Sub_Task_Order_ID,-1) --04/07/2014 Modified Sub task order mapping --- nvl((SELECT N_SUB_TASK_ORDER_ID FROM KITT_NISC3.SUB_TASK_ORDER G where A.TASK_ORDER_ID = G.N_TASK_ORDER_ID and rownum = 1 and  ('Subtask ' || A.SUB_TASK_ORDER_NUMBER) = G.C_SUB_TASK_ORDER_NAME ),-1)
                          , nvl(b.n_cm_kitt2_id,0)
                          ,c.n_employee_id
                          ,case A.COSTTYPE_ID 
                            when 1 then (select H.N_CTM_KITT2_ID from Cost_TYPE_MAP H where H.N_CTM_NAT_Labor_Type = A.SUBCOSTTYPE_ID)
                            else (select H.N_CTM_KITT2_ID from Cost_TYPE_MAP H where H.N_CTM_NAT_ID = A.CostType_ID)
                            end
                          ,case A.Costtype_Id
                              when 1 then (A.QUANTITY)
                              when 5 then (A.QUANTITY)
                              else 0
                            end
                          ,nvl(A.RAW_COST,0)
                          ,nvl(A.TOTAL_COST,0)
                          ,A.Cost_Description                            
                          ,nvl(E.N_OTM_KITT2_ID,null)
                          ,F.N_LCM_KITT2_ID
                          ,nvl((select n_Invoice_Id from KITT_NISC3.Invoice where ROWNUM = 1 AND  (cast(to_char(A.DATE_INCURRED,'yyyy') as varchar2(4)) || cast(to_Char(A.DATE_INCURRED,'MM') as varchar2(2)))= KITT_NISC3.Invoice.n_invoice_year_month),NewInvoiceID)
                          ,A.DATE_INCURRED
                          ,case A.EXTERNAL_ID
                           when '3229312266' then '322931226600'
                           when '3229312264' then '322931226400'
                           when '3229269543' then '322926954300'
                            when '3252989853' then '325298985300'
                           when '3229269542' then '322926954200'
                            when '3229667877' then '322966787700'
                           when '3213988770' then '321398877000'
                            when '3248151017' then '324815101700'
                           when '3248151016' then '324815101600'
                          when '3253561962' then '325356196200'
                           when '3253561961' then '325356196100'
                           when '3253560794' then '325356079400'
                            when '3253552324' then '325355232400'
                           when '3248188772' then '324818877200'
                            when '3248198477' then '324819847700'
                           when '3253602528' then '325360252800'
                            when '3248188773' then '324818877300'
                           when '3253633105' then '325363310500'
                           when '3273094724' then '327309472400'
                            when '3273094725' then '327309472500'
                             when '3273128072' then '327312807200'
                              when '3273128073' then '327312807300'
                              when '3273128074' then '327312807400'
                              when '3254745108' then '325474510800'
                              when  '3279464708' then '327946470800'
                              when '3273046658'   then '327304665800' 
                              when '3290783915'   then  '329078391500'
                              when '3290782906'   then  '329078290600'
                              when '3279463779'   then   '327946377900'
                              when '3288311667'   then   '328831166700' 
                              when '3213871896'   then   '321387189600' 
                              when '3316183563'   then  '331618356300'
                              when  '3316183565'  then  '331618356500'
                              when '3273046657' then  '327304665700'
                              when '3300552803' then  '330055280300'
                              when '3300550151' then '330055015100'
                              when '3290825853' then '329082585300'
                              when '3278604822002' then '327860482200200'
                              when '3252987193' then '325298719300'
                              when '3254759751' then '325475975100'
                                when '3290825860' then '329082586000'
                              when '3318769151' then '331876915100'
                              when '3316181810' then '331618181000'
                           else A.EXTERNAL_ID
                           end
                          ,0
                          ,'n/a'
                          ,cast(to_char(A.DATE_INCURRED,'yyyy') as varchar2(4)) || cast(to_Char(A.DATE_INCURRED,'MM') as varchar2(2))
FROM NAT_INVOICE_LINE_ITEM A 
left outer join Contractor_Map B on A.Company_ID = B.N_CM_NAT_ID
left outer join Employee C on A.Employee_ID = C.N_NISC_ID
--left outer join Cost_Type_Map D on A.CostType_ID = D.N_CTM_NAT_ID
left outer join ODC_TYpe_Map E on A.SUBCOSTTYPE_ID = E.N_OTM_NAT_ID
--left outer join ODC_TYpe_Map L on A.LABOR_ODC_COST_TYPE_ID = L.N_OTM_KITT3_ID
left outer join LABOR_CATEGORY_MAP F on A.LABORCATEGORY_ID = F.N_LCM_NAT_ID
--left outer join SUB_TASK_Order_MAP G on A.Sub_Task_Order_ID = G.K3_N_SUB_TASK_Order_ID
left outer join TASK_Order_Map J on A.TaskOrder = J.K3_N_Task_Order_ID
  where A.INVOICE_NUMBER = NewInvoiceID;
  
  commit;

END SP_NAT_INVOICE_LOAD_orig;
/
