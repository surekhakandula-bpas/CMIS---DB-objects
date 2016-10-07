DROP PROCEDURE P_REFRESH_REL_PRS;

CREATE OR REPLACE PROCEDURE               P_refresh_rel_prs (p_contract_num varchar2)
IS


  CURSOR c_cuff_prs is 
          SELECT PR
FROM V_TSOCUFF_AWDS@PRISM v
WHERE 1 = 1 
AND PR_STATUS ='Released'
and pr_buyer_name like 'ROBERT  GRABNER'
-- AND PR='AC-16-05419'
and ((pr_header_text like ('%NISC%') or pr_header_text like ('%DTFAWA-11-C-00003%' ) )
or (PR_DESC like ('%NISC%')  or pr_header_text like ('%DTFAWA-11-C-00003%' ) )
or (PR_LINEITEM_DESC like ('%NISC%') or pr_header_text like ('%DTFAWA-11-C-00003%' ) )
 ) 
group by pr;


 
               
   CURSOR C_CUFF_AWDS (v_pr varchar2)
   IS
        SELECT  SYSDATE EXTRACT_DATE,
                        PR,
                        PR_VERSION,
                        PR_STATUS,
                        REQ_TYPE,
                        SUM(PR_DIST_AMOUNT) PR_DIST_AMOUNT,
                        SUM(PR_DIST_COMMITTED_AMT) PR_DIST_COMMITTED_AMT,
                        REQUESTED_BY||'  '||REQUESTED_PHONE_NO POC_NAME,
                        REQUISITIONER,
                        p_contract_num CONTRACT_NUM,
                        trunc(PR_STATUSDATE)  PR_STATUS_DATE 
         FROM   V_TSOCUFF_AWDS@PRISM v
         WHERE   1 = 1 
         AND pr = v_pr 
         GROUP BY SYSDATE,
                        PR,
                        PR_VERSION,
                        PR_STATUS,
                        REQ_TYPE,                       
                        REQUESTED_BY||'  '||REQUESTED_PHONE_NO ,
                        REQUISITIONER,
                        CONTRACT_NUM,
                        trunc(PR_STATUSDATE)  ;    
BEGIN
   -- delete data from prism_pr_rel_archive table
   DELETE FROM   prism_pr_rel_archive
         WHERE   contract_num = p_contract_num;

   -- insert the data from prism_pr_rel to prism_pr_rel_archive  table
   INSERT INTO prism_pr_rel_archive
      SELECT   SYSDATE, a.*
        FROM   prism_pr_rel A
       WHERE   A.contract_num = p_contract_num;

   --P_JOB_EVENT_DETAIL('PRISM PR','Success','Successfully collected prism data from prism database for contract '|| p_contract_num );

   DELETE FROM   PRISM_PR_rel
         WHERE   contract_num = p_contract_num;
         
 FOR cuff_prs_ROW IN c_cuff_prs LOOP
 
   FOR CUFF_AWDS_ROW IN C_CUFF_AWDS(CUFF_PRS_ROW.PR)
   LOOP
      INSERT INTO PRISM_PR_rel ( 
                                EXTRACT_DATE,
                                PR,
                                PR_VERSION,
                                PR_STATUS,
                                REQ_TYPE,
                                PR_DIST_AMOUNT,
                                POC_NAME,
                                REQUISITIONER,
                                CONTRACT_NUM,
                                PR_STATUS_DATE,
                                pr_dist_COMMITTED_amt)
        VALUES   (CUFF_AWDS_ROW.EXTRACT_DATE,
                  CUFF_AWDS_ROW.PR,
                  CUFF_AWDS_ROW.PR_VERSION,
                  CUFF_AWDS_ROW.PR_status,
                  CUFF_AWDS_ROW.REQ_TYPE,
                  CUFF_AWDS_ROW.PR_DIST_AMOUNT,
                  CUFF_AWDS_ROW.POC_NAME,
                  CUFF_AWDS_ROW.REQUISITIONER,
                  CUFF_AWDS_ROW.CONTRACT_NUM,
                  CUFF_AWDS_ROW.PR_STATUS_DATE,
                  CUFF_AWDS_ROW.pr_dist_COMMITTED_amt);
   END LOOP;
  END LOOP;
--P_JOB_EVENT_DETAIL('PRISM PR','Success','Successfully loaded prism data into PRISM_PR_rel table for contract'|| p_contract_num);  DELETE FROM PRISM_PR_REL WHERE PR IN (SELECT PR FROM PRISM_PR WHERE CONTRACT_NUM =p_contract_num);


   DELETE FROM PRISM_PR_REL WHERE PR IN (SELECT PR FROM PRISM_PR WHERE CONTRACT_NUM =p_contract_num);
   
   COMMIT;
   
EXCEPTION
   WHEN OTHERS
   THEN
      ROLLBACK;
      --P_JOB_EVENT_DETAIL('PRISM PR','Fail','Failed to load prism_pr_reltable from CUFF_AWDS VIEW for contract '|| p_contract_num || '  '|| ' Oracle Error msg '|| SQLERRM);
      raise_application_error (
         -20003,
         'An error was encountered while inserting data INTO Prism PR rel for contract  - '
         || p_contract_num
         || '  '
         || SQLCODE
         || ' -ERROR- '
         || SQLERRM
      );
END P_refresh_rel_prs; 
/
