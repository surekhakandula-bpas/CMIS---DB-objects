DROP PROCEDURE P_MOVE_HOLD_TO_BASE;

CREATE OR REPLACE PROCEDURE          P_MOVE_HOLD_TO_BASE(V_ERROR_CODE OUT NUMBER, V_ERROR_BUFF OUT VARCHAR2 )  IS

PRAGMA AUTONOMOUS_TRANSACTION;

  CURSOR MOVE_HOLD_TO_BASE_TBL IS
      SELECT *
      FROM PRISM_PR_DELPHI_PO_HOLD
      WHERE nvl(C_SEND_TO_KITT,'N')='Y'
      and contract_num in (select contract_num from contract_user where contract_user = user);

   V_REC_CNT NUMBER;
   BEGIN   



    BEGIN
    --  Inserting the data from prism_pr_delphi_po_hold to prism_pr_delphi_po_hold_delete table deleted flag records 
    INSERT INTO PRISM_PR_DELPHI_PO_HOLD_DELETE 
    SELECT * FROM PRISM_PR_DELPHI_PO_HOLD
    WHERE NVL(C_DELETE,'N')='Y'
     and contract_num in (select contract_num from contract_user where contract_user = user);
                           
              
    --  if the deleted record is exists in prism_pr_Delphi_po_hold_Delete table then removing that record in prism_pr_delphi_po_hold table
    DELETE FROM  PRISM_PR_DELPHI_PO_HOLD PDH
    WHERE NVL(C_DELETE,'N')='Y'
    and contract_num in (select contract_num from contract_user where contract_user = user)
      AND EXISTS
            (SELECT 1
             FROM PRISM_PR_DELPHI_PO_HOLD_DELETE PDHD
             WHERE 1=1
              AND PDH.PO_NUMBER = PDHD.PO_NUMBER
              AND PDH.RELEASE_NUM = PDHD.RELEASE_NUM
              AND PDH.LINE_NUM = PDHD.LINE_NUM
              AND PDH.SHIPMENT_NUMBER = PDHD.SHIPMENT_NUMBER
              AND PDH.DISTRIBUTION_NUM = PDHD.DISTRIBUTION_NUM
              and pdh.pr = pdhd.pr
             -- AND PDH.NET_QTY_ORDERED  = PDHD.NET_QTY_ORDERED
              AND PDH.C_DELETE = PDHD.C_DELETE);
      --COMMIT;
      
 EXCEPTION
    WHEN OTHERS THEN
    --rollback;              
    V_ERROR_CODE :=1;
    V_ERROR_BUFF :=('Failed, an error was encountered while moving data from holding tank table to holding tank delete table - '||SQLCODE || ' -ERROR- ' || SQLERRM);     
        
   -- raise_application_error(-20022,'An error was encountered while moving data from holding tank table to holding tank delete table -'|| SQLCODE || ' -ERROR- ' || SQLERRM);
            
 END;
    
    FOR MOVE_HOLD_TO_BASE_TBL_ROW IN MOVE_HOLD_TO_BASE_TBL LOOP
    
    begin
     -- MOVING THE HODLIGN TANK RECORDS  BACK TO PRISM_PR_DELPHI_PO BASE TABLE ONCE THEY TAKE ANY ACTION  IN HOLDING TABLE AS C_SEND_TO_KITT IS  "Y"
     
     IF MOVE_HOLD_TO_BASE_TBL_ROW.RECORD_TYPE = 'NEW LINE' THEN 
     
         

     -- INSERT INTO PRIMS_PR_DELPHI_PO TABLE FROM HOLDING TANK TABLE FOR NEW LINE
      INSERT INTO PRISM_PR_DELPHI_PO
              VALUES                
               (sysdate,
                MOVE_HOLD_TO_BASE_TBL_ROW.PR,
                MOVE_HOLD_TO_BASE_TBL_ROW.REQ_TYPE,
                MOVE_HOLD_TO_BASE_TBL_ROW.PR_DESC,
                MOVE_HOLD_TO_BASE_TBL_ROW.PR_LINEITEM_DESC,
                MOVE_HOLD_TO_BASE_TBL_ROW.REQUISITIONER,
                MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_NUM,
                MOVE_HOLD_TO_BASE_TBL_ROW.PR_LI_NUM,
                MOVE_HOLD_TO_BASE_TBL_ROW.PR_DIST_AMOUNT,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_PROJECT#,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_TASK#,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_FUNDCODE,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_BLI,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_BUDGETYEAR,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_OBJECT_CLASS,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_BPAC,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_EXPENDITUREORG,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_EXPENDITURETYPE,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_SGLACCT_CODE,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_EXPENDITUREDATE,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_ACCOUNT_CODE,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_LI_NUM,
                MOVE_HOLD_TO_BASE_TBL_ROW.SHIPMENT#,
                MOVE_HOLD_TO_BASE_TBL_ROW.DIST#,
                MOVE_HOLD_TO_BASE_TBL_ROW.NAME_POC,
                MOVE_HOLD_TO_BASE_TBL_ROW.ORIGINATING_OFFICE_DATA,
                MOVE_HOLD_TO_BASE_TBL_ROW.REQUISITION_DATE,
                MOVE_HOLD_TO_BASE_TBL_ROW.CONSIGNEE_AND_DESTINATION,
                MOVE_HOLD_TO_BASE_TBL_ROW.DATES_REQUIRED,
                MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_AUTHORITY_FURNISHED,
                MOVE_HOLD_TO_BASE_TBL_ROW.TYPE_OF_FUNDS,
                MOVE_HOLD_TO_BASE_TBL_ROW.EXPENDITURE_EXPIRATION_DATE,
                MOVE_HOLD_TO_BASE_TBL_ROW.FUND_DESCRIPTION,
                MOVE_HOLD_TO_BASE_TBL_ROW.D_EXTRACT_DATE,
                MOVE_HOLD_TO_BASE_TBL_ROW.PO_NUMBER,
                MOVE_HOLD_TO_BASE_TBL_ROW.VENDOR_NAME,
                MOVE_HOLD_TO_BASE_TBL_ROW.VENDOR_SITE_CODE,
                MOVE_HOLD_TO_BASE_TBL_ROW.RELEASE_NUM,
                MOVE_HOLD_TO_BASE_TBL_ROW.LINE_ITEM,
                MOVE_HOLD_TO_BASE_TBL_ROW.MATCHING_TYPE,
                MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_ORDERED,
                MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_BILLED,
                MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_RECEIVED,
                MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_CANCELLED,
                MOVE_HOLD_TO_BASE_TBL_ROW.OBLIGATED_BALANCE,
                MOVE_HOLD_TO_BASE_TBL_ROW.PROJECT_NUMBER,
                MOVE_HOLD_TO_BASE_TBL_ROW.TASK_NUMBER,
                MOVE_HOLD_TO_BASE_TBL_ROW.CHARGE_ACCOUNT,
                MOVE_HOLD_TO_BASE_TBL_ROW.MULTIPLIER,
                MOVE_HOLD_TO_BASE_TBL_ROW.FUND,
                MOVE_HOLD_TO_BASE_TBL_ROW.BUDYEAR,
                MOVE_HOLD_TO_BASE_TBL_ROW.BPAC,
                MOVE_HOLD_TO_BASE_TBL_ROW.ORGCODE,
                MOVE_HOLD_TO_BASE_TBL_ROW.OBJECT_CLASS,
                MOVE_HOLD_TO_BASE_TBL_ROW.ACCOUNT,
                MOVE_HOLD_TO_BASE_TBL_ROW.LINE_NUM,
                MOVE_HOLD_TO_BASE_TBL_ROW.SHIPMENT_NUMBER,
                MOVE_HOLD_TO_BASE_TBL_ROW.DISTRIBUTION_NUM,
                MOVE_HOLD_TO_BASE_TBL_ROW.NET_QTY_ORDERED,
                MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_MOD#,
                MOVE_HOLD_TO_BASE_TBL_ROW.RECORD_TYPE,
                MOVE_HOLD_TO_BASE_TBL_ROW.C_HOLD,
                MOVE_HOLD_TO_BASE_TBL_ROW.C_DELETE,
                MOVE_HOLD_TO_BASE_TBL_ROW.C_SEND_TO_KITT,
                MOVE_HOLD_TO_BASE_TBL_ROW.C_CORE,
                MOVE_HOLD_TO_BASE_TBL_ROW.C_DEOBLIGATE,
                MOVE_HOLD_TO_BASE_TBL_ROW.C_EXEMPT,
                MOVE_HOLD_TO_BASE_TBL_ROW.ACTION_TAKEN_DATE,
                MOVE_HOLD_TO_BASE_TBL_ROW.PMO_NOTIFIED_FLAG,
                MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_MOD_SUBTOTAL,
                MOVE_HOLD_TO_BASE_TBL_ROW.DO_NUMBER,
                MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_TYPE);    
       ELSE
       
       -- IF MOVE_HOLD_TO_BASE_TBL_ROW.DO_NUMBER ='9999' THEN
             UPDATE PRISM_PR_DELPHI_PO
             SET   RECORD_TYPE = MOVE_HOLD_TO_BASE_TBL_ROW.RECORD_TYPE,
                   C_HOLD  = MOVE_HOLD_TO_BASE_TBL_ROW.C_HOLD,
                   C_DELETE = MOVE_HOLD_TO_BASE_TBL_ROW.C_DELETE,
                   C_SEND_TO_KITT  =MOVE_HOLD_TO_BASE_TBL_ROW.C_SEND_TO_KITT,
                   C_CORE = MOVE_HOLD_TO_BASE_TBL_ROW.C_CORE,
                   C_DEOBLIGATE = MOVE_HOLD_TO_BASE_TBL_ROW.C_DEOBLIGATE,
                   C_EXEMPT  = MOVE_HOLD_TO_BASE_TBL_ROW.C_EXEMPT,
                   ACTION_TAKEN_DATE  = MOVE_HOLD_TO_BASE_TBL_ROW.ACTION_TAKEN_DATE,
                   PMO_NOTIFIED_FLAG  = MOVE_HOLD_TO_BASE_TBL_ROW.PMO_NOTIFIED_FLAG
             WHERE  CONTRACT_NUM =MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_NUM
              AND   RELEASE_NUM = MOVE_HOLD_TO_BASE_TBL_ROW.RELEASE_NUM
              AND   LINE_item = MOVE_HOLD_TO_BASE_TBL_ROW.LINE_item
              AND   SHIPMENT_NUMBER=MOVE_HOLD_TO_BASE_TBL_ROW.SHIPMENT_NUMBER
              AND   DISTRIBUTION_NUM=MOVE_HOLD_TO_BASE_TBL_ROW.DISTRIBUTION_NUM
              AND   NET_QTY_ORDERED = MOVE_HOLD_TO_BASE_TBL_ROW.NET_QTY_ORDERED;       
              --AND   PR = MOVE_HOLD_TO_BASE_TBL_ROW.PR;             

       END IF;     
       --inserting data from prism pr_delphi_po_hold to prism_pr_delphi_po_hold_hist table before deleting in holding tank table.
        INSERT INTO prism_pr_delphi_po_hold_hist
         VALUES
        (MOVE_HOLD_TO_BASE_TBL_ROW.SEQ_NUMBER,
         SYSDATE, -- HOLD_MOVE_HIST_DATE
         MOVE_HOLD_TO_BASE_TBL_ROW.EXTRACT_DATE,
         MOVE_HOLD_TO_BASE_TBL_ROW.PR,
         MOVE_HOLD_TO_BASE_TBL_ROW.REQ_TYPE,
         MOVE_HOLD_TO_BASE_TBL_ROW.PR_DESC,
         MOVE_HOLD_TO_BASE_TBL_ROW.PR_LINEITEM_DESC,
         MOVE_HOLD_TO_BASE_TBL_ROW.REQUISITIONER,
         MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_NUM,
         MOVE_HOLD_TO_BASE_TBL_ROW.PR_LI_NUM,
         MOVE_HOLD_TO_BASE_TBL_ROW.PR_DIST_AMOUNT,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_PROJECT#,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_TASK#,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_FUNDCODE,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_BLI,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_BUDGETYEAR,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_OBJECT_CLASS,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_BPAC,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_EXPENDITUREORG,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_EXPENDITURETYPE,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_SGLACCT_CODE,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_EXPENDITUREDATE,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_ACCOUNT_CODE,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_LI_NUM,
         MOVE_HOLD_TO_BASE_TBL_ROW.SHIPMENT#,
         MOVE_HOLD_TO_BASE_TBL_ROW.DIST#,
         MOVE_HOLD_TO_BASE_TBL_ROW.NAME_POC,
         MOVE_HOLD_TO_BASE_TBL_ROW.ORIGINATING_OFFICE_DATA,
         MOVE_HOLD_TO_BASE_TBL_ROW.REQUISITION_DATE,
         MOVE_HOLD_TO_BASE_TBL_ROW.CONSIGNEE_AND_DESTINATION,
         MOVE_HOLD_TO_BASE_TBL_ROW.DATES_REQUIRED,
         MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_AUTHORITY_FURNISHED,
         MOVE_HOLD_TO_BASE_TBL_ROW.TYPE_OF_FUNDS,
         MOVE_HOLD_TO_BASE_TBL_ROW.EXPENDITURE_EXPIRATION_DATE,
         MOVE_HOLD_TO_BASE_TBL_ROW.FUND_DESCRIPTION,
         MOVE_HOLD_TO_BASE_TBL_ROW.D_EXTRACT_DATE,
         MOVE_HOLD_TO_BASE_TBL_ROW.PO_NUMBER,
         MOVE_HOLD_TO_BASE_TBL_ROW.VENDOR_NAME,
         MOVE_HOLD_TO_BASE_TBL_ROW.VENDOR_SITE_CODE,
         MOVE_HOLD_TO_BASE_TBL_ROW.RELEASE_NUM,
         MOVE_HOLD_TO_BASE_TBL_ROW.LINE_ITEM,
         MOVE_HOLD_TO_BASE_TBL_ROW.MATCHING_TYPE,
         MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_ORDERED,
         MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_BILLED,
         MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_RECEIVED,
         MOVE_HOLD_TO_BASE_TBL_ROW.QUANTITY_CANCELLED,
         MOVE_HOLD_TO_BASE_TBL_ROW.OBLIGATED_BALANCE,
         MOVE_HOLD_TO_BASE_TBL_ROW.PROJECT_NUMBER,
         MOVE_HOLD_TO_BASE_TBL_ROW.TASK_NUMBER,
         MOVE_HOLD_TO_BASE_TBL_ROW.CHARGE_ACCOUNT,
         MOVE_HOLD_TO_BASE_TBL_ROW.MULTIPLIER,
         MOVE_HOLD_TO_BASE_TBL_ROW.FUND,
         MOVE_HOLD_TO_BASE_TBL_ROW.BUDYEAR,
         MOVE_HOLD_TO_BASE_TBL_ROW.BPAC,
         MOVE_HOLD_TO_BASE_TBL_ROW.ORGCODE,
         MOVE_HOLD_TO_BASE_TBL_ROW.OBJECT_CLASS,
         MOVE_HOLD_TO_BASE_TBL_ROW.ACCOUNT,
         MOVE_HOLD_TO_BASE_TBL_ROW.LINE_NUM,
         MOVE_HOLD_TO_BASE_TBL_ROW.SHIPMENT_NUMBER,
         MOVE_HOLD_TO_BASE_TBL_ROW.DISTRIBUTION_NUM,
         MOVE_HOLD_TO_BASE_TBL_ROW.NET_QTY_ORDERED,
         MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_MOD#,
         MOVE_HOLD_TO_BASE_TBL_ROW.RECORD_TYPE,
         MOVE_HOLD_TO_BASE_TBL_ROW.C_HOLD,
         MOVE_HOLD_TO_BASE_TBL_ROW.C_DELETE,
         MOVE_HOLD_TO_BASE_TBL_ROW.C_SEND_TO_KITT,
         MOVE_HOLD_TO_BASE_TBL_ROW.C_CORE,
         MOVE_HOLD_TO_BASE_TBL_ROW.C_DEOBLIGATE,
         MOVE_HOLD_TO_BASE_TBL_ROW.C_EXEMPT,
         MOVE_HOLD_TO_BASE_TBL_ROW.ACTION_TAKEN_DATE,
         MOVE_HOLD_TO_BASE_TBL_ROW.PMO_NOTIFIED_FLAG,
         MOVE_HOLD_TO_BASE_TBL_ROW.CONTRACT_MOD_SUBTOTAL,
         MOVE_HOLD_TO_BASE_TBL_ROW.RECORD_DETAIL_TEXT,
         MOVE_HOLD_TO_BASE_TBL_ROW.DO_NUMBER,
         MOVE_HOLD_TO_BASE_TBL_ROW.AWARD_TYPE);               

    -- IF MOVE_HOLD_TO_BASE_TBL_ROW.DO_NUMBER ='9999' THEN
        DELETE FROM PRISM_PR_DELPHI_PO_HOLD
        WHERE  PO_NUMBER = MOVE_HOLD_TO_BASE_TBL_ROW.PO_NUMBER
           AND RELEASE_NUM = MOVE_HOLD_TO_BASE_TBL_ROW.RELEASE_NUM
           AND LINE_item = MOVE_HOLD_TO_BASE_TBL_ROW.LINE_item
           AND SHIPMENT_NUMBER = MOVE_HOLD_TO_BASE_TBL_ROW.SHIPMENT_NUMBER
           AND DISTRIBUTION_NUM = MOVE_HOLD_TO_BASE_TBL_ROW.DISTRIBUTION_NUM;

                    
    EXCEPTION
    WHEN OTHERS THEN
    rollback;              
    V_ERROR_CODE :=1;
    V_ERROR_BUFF :=('Failed, an error was encountered while moving data from holding tank table to prism and delphi base table '|| 'Oracle Error msg'||SQLCODE || ' -ERROR- ' || SQLERRM);     
        
    --raise_application_error(-20022,'An error was encountered while moving data from holding tank table to prism and delphi BASE Tables  - '|| 'Oracle Error msg'|| SQLCODE || ' -ERROR- ' || SQLERRM);
            
    END;
               
    END LOOP;   
    

      --P_JOB_EVENT_DETAIL('PRISM PR DELPHI PO','Success','Successfully loaded the data from Holding tank table to PRISM_PR_DELPHI_PO base Table based on action in holding tank table column send_to_kitt flag marked as "Y" ');
     
   COMMIT;
      
    V_ERROR_CODE :=0;
    V_ERROR_BUFF :='Success';
    
    
  
  EXCEPTION
    WHEN OTHERS THEN
    rollback;                         
    V_ERROR_CODE :=1;
    V_ERROR_BUFF :=('Failed, An error was encountered while moving data from holdint tank table -'|| 'Oracle Error msg'||SQLCODE || ' -ERROR- ' || SQLERRM);     
    --raise_application_error(-20022,'An error was encountered while moving data  for the contract - '|| 'Oracle Error msg'||SQLCODE || ' -ERROR- ' || SQLERRM);     
   END P_MOVE_HOLD_TO_BASE; 
/

GRANT EXECUTE ON P_MOVE_HOLD_TO_BASE TO KITT_NISC3;

GRANT EXECUTE ON P_MOVE_HOLD_TO_BASE TO KITT_NISC3_USER;
