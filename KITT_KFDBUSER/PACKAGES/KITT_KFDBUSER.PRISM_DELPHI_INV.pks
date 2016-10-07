DROP PACKAGE PRISM_DELPHI_INV;

CREATE OR REPLACE PACKAGE          prism_delphi_inv AS
/******************************************************************************
   NAME:       prism_delphi_inv
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/15/2010             1. Created this package.
******************************************************************************/

  PROCEDURE P_MOVE_DELPHI_INV_LIVE_TO_ARC; 
  PROCEDURE P_MOVE_DELPHIINV_STAGE_TO_LIVE;
  PROCEDURE P_PRISM_DELPHI_INV_MAIN;
END prism_delphi_inv; 
/

DROP PACKAGE BODY PRISM_DELPHI_INV;

CREATE OR REPLACE PACKAGE BODY               prism_delphi_inv AS

/******************************************************************************
     NAME:       P_MOVE_DELPHI_INV_LIVE_TO_ARC
     PURPOSE:    To archive data from delphi_inv to delphi_inv_archive table
  

     REVISIONS: 1.0
     Date:   10/02/2009
   ******************************************************************************/

  PROCEDURE P_MOVE_DELPHI_INV_LIVE_TO_ARC IS
    -- Selecting the prism_pr data  
  
    CURSOR C_DELPHI_INV IS
       SELECT * FROM DELPHI_INV;
--       WHERE EXISTS
--        (select 1
--         from DELPHI_INV_STAGE
--         where trunc(stage_date) = trunc(sysdate));
  
  v_delphi_inv_extract_dt date; 
 BEGIN
   
--   select DISTINCT TRUNC(extract_Date) into v_delphi_inv_extract_dt
--   from delphi_inv--_stage
--   where trunc(extract_date) = trunc(sysdate);
--   
--  IF (v_delphi_inv_extract_dt) = trunc(sysdate) THEN
  
  
   DELETE FROM DELPHI_INV_ARCHIVE WHERE TRUNC(ARCHIVE_DATE) = TRUNC(SYSDATE);


    FOR DELPHI_INV_ROW IN C_DELPHI_INV LOOP
  
    
      INSERT INTO DELPHI_INV_ARCHIVE
               (
                ARCHIVE_DATE ,                  
                EXTRACT_DATE,                   
                PO_NUMBER ,                     
                PO_REV  ,                       
                PO_TYPE,                        
                VENDOR_NAME,                    
                LINE_ITEM ,                     
                LINE_NUMBER ,                   
                LINE_TYPE ,                     
                ITEM_DESC ,                     
                RELEASE_NUMBER,                 
                REL_REV_NUM  ,                  
                SHIPMENT_NUM  ,                 
                QUANTITY_ORDERED  ,             
                QUANTITY_CANCELLED,             
                NET_QTY_ORDERED  ,              
                UOM     ,                       
                UNIT_PRICE   ,                  
                DISTRIBUTION_NUM  ,             
                CHARGE_ACCOUNT,                 
                PROJECT_NUMBER ,                
                TASK_NUMBER   ,                 
                INVOICE_NUM ,                   
                INVOICE_DATE,                   
                INV_DIST_LINE,                  
                MATCHING_TYPE ,                 
                ACCOUNT   ,                     
                INVOICE_AMOUNT ,                
                KITT_INV_AMOUNT ,               
                PAYMENT_STATUS_FLAG ,           
                RECON_FLAG)
          VALUES
               (SYSDATE,      
                DELPHI_INV_ROW.EXTRACT_DATE,                   
                DELPHI_INV_ROW.PO_NUMBER ,                     
                DELPHI_INV_ROW.PO_REV  ,                       
                DELPHI_INV_ROW.PO_TYPE,                        
                DELPHI_INV_ROW.VENDOR_NAME,                    
                DELPHI_INV_ROW.LINE_ITEM ,                     
                DELPHI_INV_ROW.LINE_NUMBER ,                   
                DELPHI_INV_ROW.LINE_TYPE ,                     
                DELPHI_INV_ROW.ITEM_DESC ,                     
                DELPHI_INV_ROW.RELEASE_NUMBER,                 
                DELPHI_INV_ROW.REL_REV_NUM  ,                  
                DELPHI_INV_ROW.SHIPMENT_NUM  ,                 
                DELPHI_INV_ROW.QUANTITY_ORDERED  ,             
                DELPHI_INV_ROW.QUANTITY_CANCELLED,             
                DELPHI_INV_ROW.NET_QTY_ORDERED  ,              
                DELPHI_INV_ROW.UOM     ,                       
                DELPHI_INV_ROW.UNIT_PRICE   ,                  
                DELPHI_INV_ROW.DISTRIBUTION_NUM  ,             
                DELPHI_INV_ROW.CHARGE_ACCOUNT,                 
                DELPHI_INV_ROW.PROJECT_NUMBER ,                
                DELPHI_INV_ROW.TASK_NUMBER   ,                 
                DELPHI_INV_ROW.INVOICE_NUM ,                   
                DELPHI_INV_ROW.INVOICE_DATE,                   
                DELPHI_INV_ROW.INV_DIST_LINE,                  
                DELPHI_INV_ROW.MATCHING_TYPE ,                 
                DELPHI_INV_ROW.ACCOUNT   ,                     
                DELPHI_INV_ROW.INVOICE_AMOUNT ,                
                DELPHI_INV_ROW.KITT_INV_AMOUNT ,               
                DELPHI_INV_ROW.PAYMENT_STATUS_FLAG ,           
                DELPHI_INV_ROW.RECON_FLAG);

    END LOOP;
             
             
     PRISM_DELPHI_DATA_PKG.P_JOB_EVENT_DETAIL('DELPHI INV','Success','Successfully loaded DELPHI data into DELPHI_INV_ARCHIVE table');
   
--   ELSE
--   
--     
--     rollback;
--     PRISM_DELPHI_DATA_PKG.P_JOB_EVENT_DETAIL('DELPHI INV','Fail','Failed to load delphi_inv data into delphi_inv_archive table since stage date is not matching with system run date and need to re-run the delph inv file from discoverer');
-- 
--     raise_application_error(-20004,
--                              'An error was encountered, no data exists in delphi_inv_stage table with todays data - ' ||  SQLCODE || ' -ERROR- ' || SQLERRM);

   
 --  END IF;
  
    -- DELETE FROM DELPHI_INV_ARCHIVE
     --WHERE TRUNC(ARCHIVE_DATE) <= ADD_MONTHS(TRUNC(SYSDATE),-24);
     --COMMIT;

  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      PRISM_DELPHI_DATA_PKG.P_JOB_EVENT_DETAIL('DELPHI INV','Fail','Failed to load delphi_inv table from delphi_inv_archive'|| '  '|| 'Oracle Error msg'|| SQLERRM);
      raise_application_error(-20004,
                              'An error was encountered while moving data from delphi_inv to delphi_inv_Archive table- ' ||
                              SQLCODE || ' -ERROR- ' || SQLERRM);
    
  END P_MOVE_DELPHI_INV_LIVE_TO_ARC;
  

/******************************************************************************
     NAME:       p_net_inv_balance
     PURPOSE:    update the inv net balance amount
  
     REVISIONS: 1.0
     Date:   10/02/2009
   ******************************************************************************/
--PROCEDURE p_net_inv_balance IS
--v_qty_ord NUMBER;
--v_net_inv_bal number;

--cursor c1 is
--select line_num, shipment_number, distribution_num ,quantity_ordered_sum, quantity_invoiced_sum, invoice_num,check_date,  inv_dist_amount
--from delphi_inv_stage
--where 1=1
--and check_status_lookup_code<>'NULL'
--and payment_status_flag ='Y'
--and check_date is not null
--order by line_num, shipment_number, distribution_num,check_date;

--cursor c2(v_line number, v_shipment  number, v_dist  number, v_check_date  date) is 
--select sum(inv_dist_amount) inv_dist_amount
--from delphi_inv_stage
--where  line_num =v_line
--and shipment_number= v_shipment
--and distribution_num =v_dist
--and check_date is not null   
--and check_status_lookup_code<>'NULL'
--and payment_status_flag ='Y'
--and check_date <= v_check_date;


--begin
--for c1_rec in c1 loop

--   v_qty_ord := c1_rec.quantity_ordered_Sum;
--  for c2_rec in c2(c1_rec.line_num, c1_rec.shipment_number, c1_rec.distribution_num, c1_rec.check_date) loop
--        v_net_inv_bal:= v_qty_ord-c2_rec.inv_dist_amount;
--        
--        update delphi_inv_stage
--        set Net_AVAILABLE_INV_BALANCE =v_net_inv_bal
--        where line_num = c1_rec.line_num
--        and shipment_number = c1_rec.shipment_number
--        and distribution_num =c1_rec.distribution_num
--        and check_date = c1_rec.check_Date
--        and check_status_lookup_code<>'NULL'
--        and payment_status_flag ='Y';
--        
--  end loop;
--end loop;

--commit;

--exception
--when others then 
--  null;



--END p_net_inv_balance;

/******************************************************************************
     NAME:       P_MOVE_DELPHIINV_STAGE_TO_LIVE
     PURPOSE:    To populate data from delphi_INV_stage to delphi_inv live table
  
     REVISIONS: 1.0
     Date:   10/02/2009
   ******************************************************************************/
  PROCEDURE P_MOVE_DELPHIINV_STAGE_TO_LIVE IS
  
    v_delphi_inv_stage_cnt number;
    v_delphi_inv_stage_date date;
  --  v_prism_stage_date date;
  
    CURSOR C_DELPHI_INV_STAGE IS  
        select *
        from delphi_inv_stage ;
        
      
  
  BEGIN
  
 
    SELECT COUNT(*) INTO v_delphi_inv_stage_cnt FROM DELPHI_INV_STAGE;
    
    SELECT DISTINCT TRUNC(STAGE_DATE) INTO v_delphi_inv_stage_date FROM DELPHI_INV_STAGE;    
  
    --select count(*) into v_delphi_po_cnt from prism_pr;

      IF v_delphi_inv_stage_cnt > 400 AND trunc(v_delphi_inv_stage_date) = trunc(sysdate) THEN      
        DELETE FROM DELPHI_INV;
        --commit;
      
       -- FOR DELPHI_INV_STAGE_ROW IN C_DELPHI_INV_STAGE LOOP
        
         FOR DELPHI_INV_STAGE_ROW IN C_DELPHI_INV_STAGE LOOP
     
          insert into delphi_inv(
                EXTRACT_DATE,                   
                PO_NUMBER ,                     
                PO_REV  ,                       
                PO_TYPE,                        
                VENDOR_NAME,                    
                LINE_ITEM ,                     
                LINE_NUMBER ,                   
                LINE_TYPE ,                     
                ITEM_DESC ,                     
                RELEASE_NUMBER,                 
                REL_REV_NUM  ,                  
                SHIPMENT_NUM  ,                 
                QUANTITY_ORDERED  ,             
                QUANTITY_CANCELLED,             
                NET_QTY_ORDERED  ,              
                UOM     ,                       
                UNIT_PRICE   ,                  
                DISTRIBUTION_NUM  ,             
                CHARGE_ACCOUNT,                 
                PROJECT_NUMBER ,                
                TASK_NUMBER   ,                 
                INVOICE_NUM ,                   
                INVOICE_DATE,                   
                INV_DIST_LINE,                  
                MATCHING_TYPE ,                 
                ACCOUNT   ,                     
                INVOICE_AMOUNT ,                
                KITT_INV_AMOUNT ,               
                PAYMENT_STATUS_FLAG ,           
                RECON_FLAG)
           values
              ( sysdate,                   
                DELPHI_INV_STAGE_ROW.PO_NUMBER ,                     
                DELPHI_INV_STAGE_ROW.PO_REV  ,                       
                DELPHI_INV_STAGE_ROW.PO_TYPE,                        
                DELPHI_INV_STAGE_ROW.VENDOR_NAME,                    
                DELPHI_INV_STAGE_ROW.LINE_ITEM ,                     
                DELPHI_INV_STAGE_ROW.LINE_NUMBER ,                   
                DELPHI_INV_STAGE_ROW.LINE_TYPE ,                     
                DELPHI_INV_STAGE_ROW.ITEM_DESC ,                     
                DELPHI_INV_STAGE_ROW.RELEASE_NUMBER,                 
                DELPHI_INV_STAGE_ROW.REL_REV_NUM  ,                  
                DELPHI_INV_STAGE_ROW.SHIPMENT_NUM  ,                 
                DELPHI_INV_STAGE_ROW.QUANTITY_ORDERED  ,             
                DELPHI_INV_STAGE_ROW.QUANTITY_CANCELLED,             
                DELPHI_INV_STAGE_ROW.NET_QTY_ORDERED  ,              
                DELPHI_INV_STAGE_ROW.UOM     ,                       
                DELPHI_INV_STAGE_ROW.UNIT_PRICE   ,                  
                DELPHI_INV_STAGE_ROW.DISTRIBUTION_NUM  ,             
                DELPHI_INV_STAGE_ROW.CHARGE_ACCOUNT,                 
                DELPHI_INV_STAGE_ROW.PROJECT_NUMBER ,                
                DELPHI_INV_STAGE_ROW.TASK_NUMBER   ,                 
                DELPHI_INV_STAGE_ROW.INVOICE_NUM ,                   
                DELPHI_INV_STAGE_ROW.INVOICE_DATE,                   
                DELPHI_INV_STAGE_ROW.INV_DIST_LINE,                  
                DELPHI_INV_STAGE_ROW.MATCHING_TYPE ,                 
                DELPHI_INV_STAGE_ROW.ACCOUNT   ,                     
                DELPHI_INV_STAGE_ROW.INVOICE_AMOUNT ,                
                DELPHI_INV_STAGE_ROW.KITT_INV_AMOUNT ,               
                DELPHI_INV_STAGE_ROW.PAYMENT_STATUS_FLAG ,           
                DELPHI_INV_STAGE_ROW.RECON_FLAG)  ;                     
                

        
        END LOOP;
        -- calling the below procedure to update the net Inv balance amount.
        --p_net_inv_balance;
        

        
       PRISM_DELPHI_DATA_PKG.P_JOB_EVENT_DETAIL('DELPHI INV','Success','Successfully loaded delphi inv data into DELPHI_INV table');
     
      END IF;
      -- COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
     ROLLBACK;
      PRISM_DELPHI_DATA_PKG.P_JOB_EVENT_DETAIL('DELPHI INV','Fail','Failed to load delphi_inv table from delphi_inv_stage'|| '  '|| 'Oracle Error msg'|| SQLERRM);
      raise_application_error(-20005,
                              'An error was encountered while inserting data from Delphi_inv_stage to delphi_inv live table - ' ||
                              SQLCODE || ' -ERROR- ' || SQLERRM);
    
  END P_MOVE_DELPHIINV_STAGE_TO_LIVE;
  
  /******************************************************************************
     NAME:       PRISM_PR_DELPHI_PO_MAIN
     PURPOSE:    Delphi main prcedure to call all other sub procedures

     REVISIONS: 1.0
     Date:   1/29/2009
   ******************************************************************************/
  PROCEDURE P_PRISM_DELPHI_INV_MAIN IS
  
  BEGIN
   
    --P_MOVE_DELPHI_INV_LIVE_TO_ARC; 
    P_MOVE_DELPHIINV_STAGE_TO_LIVE;
   -- p_error_email_notification;
     commit;
  
  END P_PRISM_DELPHI_INV_MAIN;
  


END prism_delphi_inv; 
/
