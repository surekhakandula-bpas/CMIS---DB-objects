DROP PROCEDURE SP_MIGRATION;

CREATE OR REPLACE PROCEDURE            "SP_MIGRATION" (Delete_Last_Processed_Invoice char) AS 
 NewInvoiceID number;
 InvoiceStatus number;
BEGIN
if Delete_Last_Processed_Invoice = 'Y'
  then
    -- Get Max ID for Invoice
    select Max(N_Invoice_ID) into NewInvoiceID from KITT_NISC3.Invoice;
    select n_status_number into InvoiceStatus from KITT_NISC3.Invoice where n_invoice_id = NewInvoiceId;
    if InvoiceStatus = 300
    then
      sp_delete_last_invoice();
    else
      dbms_output.put_line('Cannot delete Invoice as Status is : '||InvoiceStatus);
      return;
    end if;
  else
    -- Get new Invoice ID from sequence
   select KITT_NISC3.seq_invoice.nextval into NewInvoiceID from DUAL;    
  end if;

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
,cast(to_char(sysdate,'yyyy') as varchar2(4)) || cast(to_Char(sysdate,'MM') as varchar2(2))
,NewInvoiceID
,current_date
,'Invoice Voucher Created'
,313
, (select INVOICE_DESC from K3_INVOICE_HEADER where INVOICE_NUMBER=NewInvoiceID));

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
                          ,nvl(J.KH_N_Task_Order_Base_ID,A.base_task_order_number) --Modified 04/07/2014 --A.BASE_TASK_ORDER_NUMBER
                          ,'Subtask ' || A.SUB_TASK_ORDER_NUMBER
                         ,nvl((SELECT max(z.KH_N_SUBTASK_ORDER_ID) FROM KITT_NISC3.SUB_TASK_ORDER_MAP z where z.KH_N_Task_Order_Base_ID = J.KH_N_Task_Order_Base_ID and upper(trim(A.SUB_TASK_ORDER_NUMBER)) = upper(trim(z.k3_SUB_TASK_ORDER_NUMBER))),1)
                          --,nvl(G.KH_N_Sub_Task_Order_ID,-1) --04/07/2014 Modified Sub task order mapping --- nvl((SELECT N_SUB_TASK_ORDER_ID FROM KITT_NISC3.SUB_TASK_ORDER G where A.TASK_ORDER_ID = G.N_TASK_ORDER_ID and rownum = 1 and  ('Subtask ' || A.SUB_TASK_ORDER_NUMBER) = G.C_SUB_TASK_ORDER_NAME ),-1)
                          , nvl(b.n_cm_kitt2_id,0)
                          ,c.n_employee_id
                          ,case A.COST_TYPE_ID 
                            when 104 then (select H.N_CTM_KITT2_ID from Cost_TYPE_MAP H where H.N_CTM_KITT3_Labor_Type = A.Labor_Type_ID)
                            else (select H.N_CTM_KITT2_ID from Cost_TYPE_MAP H where H.N_CTM_KITT3_ID = A.Cost_Type_ID)
                            end -- Modified 04/07/2014 --nvl(D.N_CTM_KITT2_ID, NVL(A.COST_TYPE_ID,1) * -1)
                          ,case A.Cost_type_Id
                              when 104 then (A.COST_ITEM_QUANTITY)
                              else 0
                            end
                          ,nvl(A.COST_ITEM_RAW_COST,0)
                          ,nvl(A.COST_ITEM_TOTAL,0)
                          ,case A.Cost_type_Id 
                              when 104 then (select employee_lookup.USER_NAME@k3_prod from employee_lookup@k3_prod where employee_lookup.employee_ID@k3_prod = A.Employee_ID) || ' ' || (select Labor_Category.Labor_Category_Name@k3_prod from Labor_Category@k3_prod where Labor_Category.Labor_Category_ID@k3_prod = A.Labor_Category_ID and rownum = 1) || ' ' || A.Cost_Incurred_Date
                              when 106 then (select employee_lookup.USER_NAME@k3_prod from employee_lookup@k3_prod where employee_lookup.employee_ID@k3_prod = A.Employee_ID) || ' ' || (select Labor_Category.Labor_Category_Name@k3_prod from Labor_Category@k3_prod where Labor_Category.Labor_Category_ID@k3_prod = A.Labor_Category_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 107 then (select employee_lookup.USER_NAME@k3_prod from employee_lookup@k3_prod where employee_lookup.employee_ID@k3_prod = A.Employee_ID) || ' ' || (select Labor_Category.Labor_Category_Name@k3_prod from Labor_Category@k3_prod where Labor_Category.Labor_Category_ID@k3_prod = A.Labor_Category_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 108 then (select employee_lookup.USER_NAME@k3_prod from employee_lookup@k3_prod where employee_lookup.employee_ID@k3_prod = A.Employee_ID) || ' ' || (select Labor_Category.Labor_Category_Name@k3_prod from Labor_Category@k3_prod where Labor_Category.Labor_Category_ID@k3_prod = A.Labor_Category_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 109 then (select employee_lookup.USER_NAME@k3_prod from employee_lookup@k3_prod where employee_lookup.employee_ID@k3_prod = A.Employee_ID) || ' ' || (select Labor_Category.Labor_Category_Name@k3_prod from Labor_Category@k3_prod where Labor_Category.Labor_Category_ID@k3_prod = A.Labor_Category_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 111 then (select employee_lookup.USER_NAME@k3_prod from employee_lookup@k3_prod where employee_lookup.employee_ID@k3_prod = A.Employee_ID) || ' ' || (select Labor_Category.Labor_Category_Name@k3_prod from Labor_Category@k3_prod where Labor_Category.Labor_Category_ID@k3_prod = A.Labor_Category_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 101 then (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Material_ODC_Cost_Type_ID) || ' ' || (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Labor_ODC_Cost_Type_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 105 then (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Material_ODC_Cost_Type_ID) || ' ' || (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Labor_ODC_Cost_Type_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 112 then (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Material_ODC_Cost_Type_ID) || ' ' || (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Labor_ODC_Cost_Type_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 113 then (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Material_ODC_Cost_Type_ID) || ' ' || (select odc_cost_type.odc_Type@k3_prod || ' ' || odc_cost_type.ODC_Name@k3_prod from odc_cost_type@k3_prod where odc_cost_type.ODC_Cost_ID@k3_prod = A.Labor_ODC_Cost_Type_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 103 then (select employee_lookup.USER_NAME@k3_prod from employee_lookup@k3_prod where employee_lookup.employee_ID@k3_prod = A.Employee_ID AND ROWNUM = 1) || ' ' || A.Cost_Incurred_Date
                              when 114 then 'Direct Rate Adjustment'
                              when 116 then 'Indirect Rate Adjustment'
                              else 'N/A'
                            end
                          ,nvl(E.N_OTM_KITT2_ID,nvl(L.N_OTM_KITT2_ID,null))
                          ,F.N_LCM_KITT2_ID
                          ,nvl((select n_Invoice_Id from KITT_NISC3.Invoice where ROWNUM = 1 AND  (cast(to_char(A.COST_INCURRED_DATE,'yyyy') as varchar2(4)) || cast(to_Char(A.COST_INCURRED_DATE,'MM') as varchar2(2)))= KITT_NISC3.Invoice.n_invoice_year_month),NewInvoiceID)
                          ,A.COST_INCURRED_DATE
                          ,case A.UB_LINE_ITEM_ID
                            when '888704' then '88870400'
                            else A.UB_LINE_ITEM_ID
                           end 
                          ,0
                          ,'n/a'
                          ,cast(to_char(sysdate,'yyyy') as varchar2(4)) || cast(to_Char(sysdate,'MM') as varchar2(2))
FROM K3_INVOICE_LINE_ITEM A 
left outer join Contractor_Map B on A.Contractor_ID = B.N_CM_KITT3_ID
left outer join Employee C on A.Employee_ID = C.N_NISC_ID
--Modified 04/07/2014 -- left outer join Cost_Type_Map D on A.Cost_Type_ID = D.N_CTM_KITT3_ID
left outer join ODC_TYpe_Map E on A.MATERIAL_ODC_COST_TYPE_ID = E.N_OTM_KITT3_ID
left outer join ODC_TYpe_Map L on A.LABOR_ODC_COST_TYPE_ID = L.N_OTM_KITT3_ID
left outer join LABOR_CATEGORY_MAP F on A.LABOR_CATEGORY_ID = F.N_LCM_KITT3_ID
--left outer join SUB_TASK_Order_MAP G on A.Sub_Task_Order_ID = G.K3_N_SUB_TASK_Order_ID
left outer join TASK_Order_Map J on A.Task_Order_ID = J.K3_N_Task_Order_ID
  where A.INVOICE_ID = (SELECT INVOICE_ID FROM K3_INVOICE_HEADER WHERE INVOICE_NUMBER = NewInvoiceID);
  
  commit;
 --SP_INVOICE_LOADING_AUDITS();
END SP_MIGRATION;
/
