DROP PACKAGE PRISM_DELPHI_DATA_PKG;

CREATE OR REPLACE PACKAGE               PRISM_DELPHI_DATA_PKG AS
/******************************************************************************
   NAME:     PRISM_DELPHI_DATA_PKG
   Purpose : Populate the Prism requisition and Delphi purchase order information
             to KITT's database to be used to track task orders.

   REVISIONS:
   Ver        Date        Author
   ---------  ----------  ---------------
   1.0        1/29/2009    Surekha Kandula
******************************************************************************/

  PROCEDURE P_MOVE_PRISM_PR_STAGE(p_contract_num varchar2)  ;
  
  FUNCTION F_IDENTIFY_DELTA(p_contract_num varchar2)  RETURN NUMBER;
  PROCEDURE P_MOVE_PRISM_LIVE_TO_ARCHIVE(p_contract_num varchar2)  ;
  PROCEDURE P_PRISM_UPDATE_STAGE_TBL;
  PROCEDURE P_MOVE_PRISM_STAGE_TO_LIVE(p_contract_num varchar2) ;
  PROCEDURE P_MOVE_DELPHI_LIVE_TO_ARCHIVE(p_contract_num varchar2)  ;
  PROCEDURE P_MOVE_DELPHI_STAGE_TO_LIVE(p_contract_num varchar2) ;
  PROCEDURE P_MOVE_PRISM_PR_DELPHI_PO(p_contract_num varchar2) ;
  PROCEDURE P_MOVE_PRISM_DELPHI_LIVE_TO_AR;
  PROCEDURE P_PRISM_PR_DELPHI_PO_MAIN;
  PROCEDURE P_JOB_EVENT_DETAIL(p_event_module_nm varchar2,
                               p_event_short_desc varchar2,
                               p_event_long_desc varchar2
                               );

  PROCEDURE P_BUSINESS_LOGIC_AUDIT_LOGS
                              (p_event_short_desc varchar2,
                               p_event_long_desc varchar2
                               );
  PROCEDURE P_MOVE_PRISM_DELPHI_TO_HOLD(p_contract_num varchar2) ;
 -- PROCEDURE P_MOVE_HOLD_TO_BASE_XXX(V_ERROR_CODE OUT NUMBER, V_ERROR_BUFF OUT VARCHAR2);
  PROCEDURE p_changes_email_notification(p_contract_num varchar2)  ;
  PROCEDURE p_changes_email_notification1(p_contract_num varchar2)  ;
  --PROCEDURE P_MOVE_DELPHI_INV_LIVE_TO_ARC;
 -- PROCEDURE P_MOVE_DELPHIINV_STAGE_TO_LIVE;
  PROCEDURE p_error_email_notification;
  PROCEDURE P_update_reqformod_prs;
  PROCEDURE P_AVOID_DUP_PRS_EXCEPTION(p_contract_num varchar2)  ;
END PRISM_DELPHI_DATA_PKG; 
/

DROP PACKAGE BODY PRISM_DELPHI_DATA_PKG;

CREATE OR REPLACE PACKAGE BODY               PRISM_DELPHI_DATA_PKG
AS
   /******************************************************************************
        PUR     NAME:      P_IDENTIFY_DELTA
       POSE:   Procedure to IDENTIFY THE DATA BETWEEN YESTRDAY AND TODAY'S DATA FROM DLEPHI_PO_ARCHIVE AND DELPHI_PO_STAGE TABLE
        REVISIONS: 1.0
        Date:   1/29/2009
      ******************************************************************************/
   FUNCTION F_IDENTIFY_DELTA (p_contract_num varchar2)
      RETURN NUMBER
   IS
      V_COUNT   NUMBER := 0;
   BEGIN
   
       DELETE FROM   DELPHI_PO_STAGE
               WHERE   1=1--po_number = p_contract_num
                       AND (    line_num = 2875
                            AND distribution_num = 123
                            AND net_qty_ordered = 0.01);
                            commit;
      SELECT   COUNT ( * )
        INTO   V_COUNT
        FROM   (SELECT   po_number,
                         release_num,
                         line_num,
                         shipment_number,
                         distribution_num,
                         net_qty_ordered,
                         quantity_billed
                  FROM   delphi_po_stage
                 WHERE   po_number = p_contract_num
                MINUS
                SELECT   po_number,
                         release_num,
                         line_num,
                         shipment_number,
                         distribution_num,
                         net_qty_ordered,
                         quantity_billed
                  FROM   delphi_po
                 WHERE   1 = 1 AND po_number = p_contract_num);


      IF V_COUNT = 0
      THEN
         RETURN 0;
      ELSE
         RETURN 1;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN 2;
   END F_IDENTIFY_DELTA;

   /******************************************************************************
            PUR     NAME:      P_MOVE_PRISM_PR_STAGE
 POSE:   Procedure to MOVE DATA into prism_pr_stage table from PRISM databse.
      REVISIONS: 1.0
      Date:   1/29/2009
    ******************************************************************************/
   PROCEDURE P_MOVE_PRISM_PR_STAGE (p_contract_num varchar2)
   IS
      v_prism_pr_stage_cnt   number;
      v_prism_stage_date     date;
      v_delphi_stage_date    date;

      CURSOR C_CUFF_AWDS
      IS
           SELECT   SYSDATE STAGE_DATE,
                    PR,
                    REQ_TYPE,
                    PR_DESC,
                    PR_LINEITEM_DESC,
                    REQUISITIONER,
                    CONTRACT_NUM,
                    (PR_LI_NUM),
                    (PR_DIST_AMOUNT),
                    AWARD_PROJECT#,
                    AWARD_TASK#,
                    AWARD_FUNDCODE,
                    AWARD_BLI,
                    AWARD_BUDGETYEAR,
                    AWARD_OBJECT_CLASS,
                    AWARD_BPAC,
                    AWARD_EXPENDITUREORG,
                    AWARD_EXPENDITURETYPE,
                    AWARD_SGLACCT_CODE,
                    TO_CHAR (AWARD_EXPENDITUREDATE, 'DD-MON-YYYY')
                       AWARD_EXPENDITUREDATE,
                    AWARD_ACCOUNT_CODE,
                    (AWARD_LI_NUM),
                    (shipment#),
                    Account_id DIST#,
                    NVL (pr_line_status, 'Fully Awarded') pr_line_status,
                    AWARD_LINE_STATUS,
                    REQUESTED_BY || '  ' || REQUESTED_PHONE_NO POC_NAME,
                    ORIGINATION_OFFICE,
                    ORIGINATION_OFFICE_NAME,
                    REQUISITIONER_INFO,
                    TO_CHAR (REQUISITION_DATE, 'DD-MON-YYYY') REQUISITION_DATE,
                       REQ_DEL_LOC_NM
                    || ' '
                    || REQ_DELIVERY_ADDR
                    || ' '
                    || REQ_DELIVERY_CITY
                    || ' '
                    || REQ_DELIVERY_STATE_ZIP
                       CONSIGNEE_AND_DESTINATION,
                    TO_CHAR (REQ_DELIVERY_DATE, 'DD-MON-YYYY')
                       REQ_DELIVERY_DATE,
                    GFE CONTRACT_AUTHORITY_FURNISHED,
                    AWARD_DIST_OBLIG_AMT,
                    mod_num CONTRACT_MOD,
                    PR_DIST_COMMITTED_AMT,
                    TO_CHAR (REQ_APPROVED_DATE, 'DD-MON-YYYY')
                       REQ_APPROVED_DATE,
                    NVL (DO_num, '9999') DO_NUM,
                    AWARD_TYPE,
                    PR_VERSION
             FROM   V_TSOCUFF_AWDS@PRISM v
            WHERE   1 = 1 AND contract_num = p_contract_num
         ORDER BY   contract_num,
                    do_num,
                    award_li_num,
                    shipment#,
                    dist#;
   BEGIN
      P_JOB_EVENT_DETAIL (
         'PRISM PR',
         'Success',
         'Successfully collected prism data from prism database for contract '
         || p_contract_num
      );

      DELETE FROM   PRISM_PR_STAGE
            WHERE   contract_num = p_contract_num;

      FOR CUFF_AWDS_ROW IN C_CUFF_AWDS
      LOOP
         INSERT INTO PRISM_PR_STAGE (stage_date,
                                     PR,
                                     REQ_TYPE,
                                     pr_desc,
                                     pr_lineitem_desc,
                                     REQUISITIONER,
                                     REQUISITIONER_INFO,
                                     CONTRACT_NUM,
                                     PR_LI_NUM,
                                     PR_DIST_AMOUNT,
                                     AWARD_PROJECT#,
                                     AWARD_TASK#,
                                     AWARD_FUNDCODE,
                                     AWARD_BLI,
                                     AWARD_BUDGETYEAR,
                                     AWARD_OBJECT_CLASS,
                                     AWARD_BPAC,
                                     AWARD_EXPENDITUREORG,
                                     AWARD_EXPENDITURETYPE,
                                     AWARD_SGLACCT_CODE,
                                     AWARD_EXPENDITUREDATE,
                                     AWARD_ACCOUNT_CODE,
                                     AWARD_LI_NUM,
                                     SHIPMENT#,
                                     DIST#,
                                     pr_line_status,
                                     NAME_POC,
                                     ORIGINATING_OFFICE,
                                     ORIGINATION_OFFICE_NAME,
                                     REQUISITION_DATE,
                                     CONSIGNEE_AND_DESTINATION,
                                     DATES_REQUIRED,
                                     CONTRACT_AUTHORITY_FURNISHED,
                                     AWARD_DIST_OBLIG_AMT,
                                     CONTRACT_MOD#,
                                     REQ_APPROVED_DATE,
                                     PR_DIST_COMMITTED_AMT,
                                     DO_NUMBER,
                                     AWARD_TYPE,
                                     PR_VERSION)
           VALUES   (CUFF_AWDS_ROW.STAGE_DATE,
                     CUFF_AWDS_ROW.PR,
                     CUFF_AWDS_ROW.REQ_TYPE,
                     CUFF_AWDS_ROW.PR_DESC,
                     CUFF_AWDS_ROW.PR_LINEITEM_DESC,
                     CUFF_AWDS_ROW.REQUISITIONER,
                     CUFF_AWDS_ROW.REQUISITIONER_INFO,
                     CUFF_AWDS_ROW.CONTRACT_NUM,
                     CUFF_AWDS_ROW.PR_LI_NUM,
                     CUFF_AWDS_ROW.PR_DIST_AMOUNT,
                     CUFF_AWDS_ROW.AWARD_PROJECT#,
                     CUFF_AWDS_ROW.AWARD_TASK#,
                     CUFF_AWDS_ROW.AWARD_FUNDCODE,
                     CUFF_AWDS_ROW.AWARD_BLI,
                     CUFF_AWDS_ROW.AWARD_BUDGETYEAR,
                     CUFF_AWDS_ROW.AWARD_OBJECT_CLASS,
                     CUFF_AWDS_ROW.AWARD_BPAC,
                     CUFF_AWDS_ROW.AWARD_EXPENDITUREORG,
                     CUFF_AWDS_ROW.AWARD_EXPENDITURETYPE,
                     CUFF_AWDS_ROW.AWARD_SGLACCT_CODE,
                     CUFF_AWDS_ROW.AWARD_EXPENDITUREDATE,
                     CUFF_AWDS_ROW.AWARD_ACCOUNT_CODE,
                     CUFF_AWDS_ROW.AWARD_LI_NUM,
                     CUFF_AWDS_ROW.SHIPMENT#,
                     CUFF_AWDS_ROW.DIST#,
                     CUFF_AWDS_ROW.PR_LINE_STATUS,
                     CUFF_AWDS_ROW.POC_NAME,
                     CUFF_AWDS_ROW.ORIGINATION_OFFICE,
                     CUFF_AWDS_ROW.ORIGINATION_OFFICE_NAME,
                     CUFF_AWDS_ROW.REQUISITION_DATE,
                     CUFF_AWDS_ROW.CONSIGNEE_AND_DESTINATION,
                     CUFF_AWDS_ROW.REQ_DELIVERY_DATE,
                     CUFF_AWDS_ROW.CONTRACT_AUTHORITY_FURNISHED,
                     CUFF_AWDS_ROW.AWARD_DIST_OBLIG_AMT,
                     CUFF_AWDS_ROW.CONTRACT_MOD,
                     CUFF_AWDS_ROW.REQ_APPROVED_DATE,
                     CUFF_AWDS_ROW.PR_DIST_COMMITTED_AMT,
                     CUFF_AWDS_ROW.DO_NUM,
                     CUFF_AWDS_ROW.AWARD_TYPE,
                     CUFF_AWDS_ROW.PR_VERSION);
      END LOOP;



      P_JOB_EVENT_DETAIL (
         'PRISM PR',
         'Success',
         'Successfully loaded prism data into PRISM_PR_STAGE table for contract'
         || p_contract_num
      );
   --COMMIT;

   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Fail',
            'Failed to load prism_pr_STAGE table from CUFF_AWDS VIEW for contract '
            || p_contract_num
            || '  '
            || ' Oracle Error msg '
            || SQLERRM
         );
         raise_application_error (
            -20003,
            'An error was encountered while inserting data INTO Prism PR stage for contract  - '
            || p_contract_num
            || '  '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_MOVE_PRISM_PR_STAGE;

   /******************************************************************************
         /******************************************************************************
      NAME:      P_MOVE_PRISM_LIVE_TO_ARCHIVE
      PURPOSE:   Procedure to archive PRISM PR data.
      REVISIONS: 1.0
      Date:   1/29/2009
    ******************************************************************************/
   PROCEDURE P_MOVE_PRISM_LIVE_TO_ARCHIVE (p_contract_num VARCHAR2)
   IS
      v_err             varchar2 (300) := NULL;

      -- Selecting the prism_pr data
      CURSOR C_PRISM_PR
      IS
         SELECT   *
           FROM   PRISM_PR
          WHERE   1 = 1 AND CONTRACT_NUM = p_contract_num
                  AND EXISTS
                        (SELECT   1
                           FROM   prism_pr_stage
                          WHERE       1 = 1
                                  AND contract_num = p_contract_num
                                  AND TRUNC (stage_date) = TRUNC (SYSDATE));

      v_prsm_stage_dt   date;
   BEGIN
      SELECT   DISTINCT TRUNC (stage_Date)
        INTO   v_prsm_stage_dt
        FROM   prism_pr_stage
       WHERE   contract_num = p_contract_num;

      IF (v_prsm_stage_dt) = TRUNC (SYSDATE)
      THEN
         DELETE FROM   PRISM_PR_ARCHIVE
               WHERE   TRUNC (ARCHIVE_DATE) = TRUNC (SYSDATE)
                       AND contract_num = p_contract_num;

         FOR PRISM_PR_ROW IN C_PRISM_PR
         LOOP
            -- inserting data from prism pr to prism pr archive table
            INSERT INTO prism_pr_archive
              VALUES   (SYSDATE,
                        PRISM_PR_ROW.EXTRACT_DATE,
                        PRISM_PR_ROW.PR,
                        PRISM_PR_ROW.REQ_TYPE,
                        PRISM_PR_ROW.PR_DESC,
                        PRISM_PR_ROW.PR_LINEITEM_DESC,
                        PRISM_PR_ROW.REQUISITIONER,
                        PRISM_PR_ROW.REQUISITIONER_INFO,
                        PRISM_PR_ROW.CONTRACT_NUM,
                        PRISM_PR_ROW.PR_LI_NUM,
                        PRISM_PR_ROW.PR_DIST_AMOUNT,
                        PRISM_PR_ROW.AWARD_PROJECT#,
                        PRISM_PR_ROW.AWARD_TASK#,
                        PRISM_PR_ROW.AWARD_FUNDCODE,
                        PRISM_PR_ROW.AWARD_BLI,
                        PRISM_PR_ROW.AWARD_BUDGETYEAR,
                        PRISM_PR_ROW.AWARD_OBJECT_CLASS,
                        PRISM_PR_ROW.AWARD_BPAC,
                        PRISM_PR_ROW.AWARD_EXPENDITUREORG,
                        PRISM_PR_ROW.AWARD_EXPENDITURETYPE,
                        PRISM_PR_ROW.AWARD_SGLACCT_CODE,
                        PRISM_PR_ROW.AWARD_EXPENDITUREDATE,
                        PRISM_PR_ROW.AWARD_ACCOUNT_CODE,
                        PRISM_PR_ROW.AWARD_LI_NUM,
                        PRISM_PR_ROW.SHIPMENT#,
                        PRISM_PR_ROW.DIST#,
                        PRISM_PR_ROW.NAME_POC,
                        PRISM_PR_ROW.ORIGINATING_OFFICE,
                        PRISM_PR_ROW.ORIGINATION_OFFICE_NAME,
                        PRISM_PR_ROW.REQUISITION_DATE,
                        PRISM_PR_ROW.CONSIGNEE_AND_DESTINATION,
                        PRISM_PR_ROW.DATES_REQUIRED,
                        PRISM_PR_ROW.CONTRACT_AUTHORITY_FURNISHED,
                        PRISM_PR_ROW.TYPE_OF_FUNDS,
                        PRISM_PR_ROW.EXPENDITURE_EXPIRATION_DATE,
                        PRISM_PR_ROW.FUND_DESCRIPTION,
                        PRISM_PR_ROW.PR_LINE_STATUS,
                        PRISM_PR_ROW.AWARD_DIST_OBLIG_AMT,
                        PRISM_PR_ROW.CONTRACT_MOD#,
                        PRISM_PR_ROW.OBLIGATION_EXPIRATION_DATE,
                        PRISM_PR_ROW.PR_LINE_TOTAL_AMT,
                        PRISM_PR_ROW.REQ_APPROVED_DATE,
                        PRISM_PR_ROW.DO_NUMBER,
                        PRISM_PR_ROW.AWARD_TYPE,
                        PRISM_PR_ROW.PR_VERSION);
         END LOOP;

         -- calling job detail procedure to update the job detail information
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Success',
            'Successfully Loaded PRISM data into PRISM_PR_ARCHIVE table for contract '
            || p_contract_num
         );
      ELSE
         ROLLBACK;
         v_err :=
            'since Prism Stage table state date is not matching with the system run date';
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Fail',
            'Failed to load date from prism_pr to prism_pr_archive table   for contract '
            || p_contract_num
            || v_err
         );
         raise_application_error (-20004, 'Application Error');
      END IF;
   -- deleting the data from pris pr archive table if the data is exist more then two year.
   --DELETE FROM PRISM_PR_ARCHIVE
   --WHERE TRUNC(ARCHIVE_DATE) <= ADD_MONTHS(TRUNC(SYSDATE),-24);
   --   COMMIT;

   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Fail',
            'Failed to load date from prism_pr to prism_pr_archive table  for contract '
            || p_contract_num
            || v_err
            || ' Oracle Err msg '
            || SQLERRM
         );

         raise_application_error (
            -20001,
            'An error was encountered while moving data from Prism live to Archive table- '
            || SQLCODE
            || ' -Oracle Error msg- '
            || SQLERRM
         );
   END P_MOVE_PRISM_LIVE_TO_ARCHIVE;

   /******************************************************************************
            NAME:       P_PRISM_UPDATE_STAGET_TBL
      PURPOSE:    To update the prism_pr_stage table with fund_description,type_of_fund
                   & EXPENDITURE_EXPIRATION_DATE
      REVISIONS:  1.0
      Date:       //29/2009
   ******************************************************************************/

   PROCEDURE P_PRISM_UPDATE_STAGE_TBL
   IS
   BEGIN
      -- update   fund_description for given award_fundcode in PRISM_PR_STAGE table
      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E, ACTIVITIES OTHER THAN PCB&T, NATIONAL'
       WHERE   AWARD_FUNDCODE = '12182A0090';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E, ACTIVITIES OTHER THAN PCB&T, AATF'
       WHERE   AWARD_FUNDCODE = '12082A0080';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'OPS, GENERAL FUND'
       WHERE   AWARD_FUNDCODE = '1280100080';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'OPS, GENERAL FUND LIM 9'
       WHERE   AWARD_FUNDCODE = '1280100089';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'GRANTS-IN-AID FOR AIRPORTS, AATF A-DIRECT'
       WHERE   AWARD_FUNDCODE = '12881A0080';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E, ACTIVITIES OTHER THAN PCB&T, AATF'
       WHERE   AWARD_FUNDCODE = '12882A0000';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E, AATF, REIMB'
       WHERE   AWARD_FUNDCODE = '12882R0009';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E, PCB&T AIRPORT AND AIRWAY TRUST FUND'
       WHERE   AWARD_FUNDCODE = '12882W0080';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'OPS, GENERAL FUND'
       WHERE   AWARD_FUNDCODE = '1290100090';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E, ACTIVITIES OTHER THAN PCB&T, AATF'
       WHERE   AWARD_FUNDCODE = '12982A0070';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E AATF REIMBURSABLE INTERNATIONAL'
       WHERE   AWARD_FUNDCODE = '12N82R0008';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'F&E AATF REIMBURSABLE NON FEDERAL SOURCES'
       WHERE   AWARD_FUNDCODE = '12N82R0077';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'FRANCHISE FUND, NATIONAL'
       WHERE   AWARD_FUNDCODE = '12X3000000';

      UPDATE   prism_pr_stage
         SET   fund_description =
                  'FACILITIES, & EQUIPMENT, AIRPORT &  AIRWAY TRUST FUND, FED AVIATION ADMIN'
       WHERE   award_fundcode = '12X8200001';

      UPDATE   prism_pr_stage
         SET   fund_description =
                  'OPERATIONS, FEDERAL AVIATION ADMINISTRATION'
       WHERE   award_fundcode = '1290100099';

      -- added on Mar 25th 2009
      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'FY2007/2009, RE&D, AATF'
       WHERE   AWARD_FUNDCODE = '1298800070';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description =
                  'FY2009, GRANTS-IN-AID FOR AIRPORTS, AATF A-DIRECT'
       WHERE   AWARD_FUNDCODE = '12981A0090';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'NO YR F&E AATF REIMBURSABLE LIM 9'
       WHERE   AWARD_FUNDCODE = '12N82R0009';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'NO YR, F&E, FAA (ALL OTHER)'
       WHERE   AWARD_FUNDCODE = '12X8200000';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'GRANTS-IN-AID FOR AIRPORTS, AATF A-DIRECT'
       WHERE   AWARD_FUNDCODE = '12081A0100';

      UPDATE   PRISM_PR_STAGE
         SET   Fund_description = 'FY2010/2012, F&E, OTHER THAN PCB&T, AATF'
       WHERE   AWARD_FUNDCODE = '12282A0100';

      -- added on Dec 8th
      UPDATE   prism_pr_stage
         SET   FUND_DESCRIPTION = 'FY2010, OPS, GENERAL FUND'
       WHERE   award_fundcode = '1200100100';

      -- update  type_of_funds and EXPENDITURE_EXPIRATION_DATE  for given award_fundcode in prism_pr_stage table


      -- UPDATE TYPE OF FUNDS AND FUND DESCRIPTION FIELDS
      -- ARRA ( 6th and 7th charactors should be 'AS')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'ARRA',
               FUND_DESCRIPTION = 'FACILITIES, & EQUIPMENT, RECOVERY ACT'
       WHERE   SUBSTR (award_fundcode, 6, 2) = ('AS')
               AND SUBSTR (award_fundcode, 3, 1) <> 'X';

      -- OPS (award_fundcode 4th and 5th charactors should be '01')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'OPS'
       --FUND_DESCRIPTION ='OPS, GENERAL FUND'
       WHERE       SUBSTR (award_fundcode, 4, 2) = ('01')
               AND SUBSTR (award_fundcode, 6, 2) <> ('AS')
               AND SUBSTR (award_fundcode, 3, 1) <> 'X';

      --GRANTS (award_fundcode 4th and 5th charactors should be '81')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'GRANTS'
       --FUND_DESCRIPTION ='GRANTS-IN-AID FOR AIRPORTS, AATF A-DIRECT'
       WHERE       SUBSTR (award_fundcode, 4, 2) = ('81')
               AND SUBSTR (award_fundcode, 6, 2) <> ('AS')
               AND SUBSTR (award_fundcode, 3, 1) <> 'X';

      --F&E (award_fundcode 4th and 5th charactors should be '82')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'F&E'
       --FUND_DESCRIPTION ='F&E, ACTIVITIES OTHER THAN PCB&T, AATF'
       WHERE       SUBSTR (award_fundcode, 4, 2) = ('82')
               AND SUBSTR (award_fundcode, 6, 2) <> ('AS')
               AND SUBSTR (award_fundcode, 3, 1) <> 'X'
               AND SUBSTR (award_fundcode, 6, 1) <> ('W');


      --PCB&T (award_fundcode 4th and 5th 6th charactors should be '82W')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'PCB&T'
       --FUND_DESCRIPTION ='F&E, ACTIVITIES OTHER THAN PCB&T, AATF'
       WHERE       SUBSTR (award_fundcode, 4, 3) = ('82W')
               AND SUBSTR (award_fundcode, 6, 2) <> ('AS')
               AND SUBSTR (award_fundcode, 3, 1) <> 'X'
               AND SUBSTR (award_fundcode, 6, 1) = ('W');

      --RE&D (award_fundcode 4th and 5th charactors should be '88')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'RE&D'
       --FUND_DESCRIPTION ='FY2007/2009, RE&D, AATF'
       WHERE       SUBSTR (award_fundcode, 4, 2) = ('88')
               AND SUBSTR (award_fundcode, 6, 2) <> ('AS')
               AND SUBSTR (award_fundcode, 3, 1) <> 'X';


      --REIMB (award_fundcode 4th,5th & 6th charactors should be '82R')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'REIMB'
       --FUND_DESCRIPTION ='F&E AATF REIMBURSABLE INTERNATIONAL'
       WHERE       SUBSTR (award_fundcode, 4, 3) = ('82R')
               AND SUBSTR (award_fundcode, 6, 2) <> ('AS')
               AND SUBSTR (award_fundcode, 3, 1) <> 'X';


      --FRANCH (award_fundcode 3rd charactor should be 'X')
      UPDATE   PRISM_PR_STAGE
         SET   TYPE_OF_FUNDS = 'FRANCH'
       --FUND_DESCRIPTION ='FRANCHISE FUND, NATIONAL'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('X');

      -- commented the below line on May 27th for suzy's request.
      --AND substr(award_fundcode,6,2) <> ('AS');

      --UPDATE EXPENDITURE EXPIRATION DATE FIELD:

      -- expire 2013 ( 3rd charactor should be 8)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2013'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('8');

      -- expire 2014 ( 3rd charactor should be 9)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2014'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('9');

      -- expire 2015 ( 3rd charactor should be 0)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2015'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('0');

      -- expire 2016 ( 3rd charactor should be 1)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2016'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('1');

      -- expire 2017 ( 3rd charactor should be 2)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2017'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('2');

      -- expire 2018 ( 3rd charactor should be 3)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2018'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('3');

      -- expire 2019 ( 3rd charactor should be 4)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2019'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('4');


      -- expire 2020 ( 3rd charactor should be 5)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2020'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('5');


      -- expire 2020 ( 3rd charactor should be 6)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2021'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('6');

      -- expire 2020 ( 3rd charactor should be 7)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2022'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('7');

      -- expire 2020 ( 3rd charactor should be 8)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2023'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('8');


      -- expire 2020 ( 3rd charactor should be 9)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2024'
       WHERE   SUBSTR (award_fundcode, 3, 1) = ('9');



      -- expire 2099 ( 3rd charactor should not be 8,9,0,1)
      UPDATE   PRISM_PR_STAGE
         SET   expenditure_expiration_date = '09/30/2099'
       WHERE   SUBSTR (award_fundcode, 3, 1) IN ('N', 'X');


      P_JOB_EVENT_DETAIL (
         'PRISM PR',
         'Success',
         'Successfully updated the fund related columns in PRISM_PR_STAGE table '
      );
   -- COMMIT;

   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Fail',
            'Failed to update prism_pr_stage table with fund related columns'
            || '  '
            || 'Oracle Error msg '
            || SQLERRM
         );
         raise_application_error (
            -20002,
               'An error was encountered while updating stage table- '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_PRISM_UPDATE_STAGE_TBL;

   /******************************************************************************
            NAME:       P_UPDATE_PRISM_LI_TOTAL_AMT
      PURPOSE:    To populate the Pris_li_totalamt field in Prism PR table
                  table.
      REVISIONS:
      Ver        Date        Author
      ---------  ----------  ---------------
      1.0        1/13/2010   Surekha
     ******************************************************************************/
   PROCEDURE P_UPDATE_PRISM_LI_TOTAL_AMT (p_contract_num VARCHAR2)
   IS
      CURSOR c1
      IS
           SELECT   pr, pr_li_num, SUM (pr_dist_amount) Total_pr_dist_amt
             FROM   prism_pr
            WHERE   contract_num = p_contract_num
         GROUP BY   pr, pr_li_num;

      CURSOR c2
      IS
         SELECT   award_fundcode,
                  -- decode(substr(award_fundcode,3,1),'8','30-SEP-2008','9','30-SEP-2009','0','30-SEP-2010','1','30-SEP-2011','2','30-SEP-2012','30-SEP-2099') obligation_exp_date
                  DECODE (SUBSTR (award_fundcode, 3, 1),
                          '8', '30-SEP-2008',
                          '9', '30-SEP-2009',
                          '0', '30-SEP-2010',
                          '1', '30-SEP-2011',
                          '2', '30-SEP-2012',
                          '3', '30-SEP-2013',
                          '4', '30-SEP-2014',
                          '5', '30-SEP-2015',
                          '6', '30-SEP-2016',
                          '7', '30-SEP-2017',
                          '8', '30-SEP-2018',
                          '9', '30-SEP-2019',
                          '30-SEP-2099')
                     obligation_exp_date
           FROM   prism_pr
          WHERE   contract_num = p_contract_num;
   BEGIN
      FOR c_row IN c1
      LOOP
         UPDATE   prism_pr
            SET   pr_line_total_amt = c_row.Total_pr_dist_amt
          WHERE   pr = c_row.pr AND pr_li_num = c_row.pr_li_num;
      END LOOP;


      FOR c2_row IN c2
      LOOP
         UPDATE   prism_pr
            SET   obligation_expiration_date = c2_row.obligation_exp_date
          WHERE   award_fundcode = c2_row.award_fundcode;
      END LOOP;
   END P_UPDATE_PRISM_LI_TOTAL_AMT;

   /******************************************************************************
                                         NAME:       P_MOVE_PRISM_STAGE_TO_LIVE
     PURPOSE:    To populate Prism PR data from PRISM_PR_STAGE to PRISM_PR
                 table.
     REVISIONS:
     Ver        Date        Author
     ---------  ----------  ---------------
     1.0        1/29/2009   Surekha
  ******************************************************************************/

   PROCEDURE P_MOVE_PRISM_STAGE_TO_LIVE (p_contract_num varchar2)
   IS
      v_prism_pr_stage_cnt   number;
      v_prism_stage_date     date;
      v_delphi_stage_date    date;

      --v_prism_pr_cnt       number;
      

      CURSOR C_PRISM_PR_STAGE
      IS
           -- select all non released fully awarded records from prism_pr_stage table and also same record (LSD) exists in delphi_po table
           SELECT   DISTINCT *
             FROM   (SELECT   *
                       FROM   PRISM_PR_STAGE PRS
                      WHERE   (PR_LINE_STATUS) = 'Fully Awarded'
                              AND contract_num = p_contract_num
                              AND ( (REQ_TYPE = 'REQUISITION'
                                     AND AWARD_DIST_OBLIG_AMT <> 0)
                                   OR (NVL (REQ_TYPE, 'REQFORMOD') =
                                          'REQFORMOD'))         --7433  --7377
                              AND DO_NUMBER <> '9999'
                              AND EXISTS
                                    (SELECT   1
                                       FROM   DELPHI_PO d
                                      WHERE   1 = 1
                                              AND prs.CONTRACT_NUM =
                                                    d.PO_NUMBER
                                              -- AND prs.AWARD_LI_NUM = d.LINE_NUM
                                              AND prs.SHIPMENT# =
                                                    d.SHIPMENT_NUMBER
                                              AND prs.DIST# =
                                                    d.DISTRIBUTION_NUM
                                              AND prs.do_number = d.release_num
                                              AND D.RELEASE_NUM <> '9999')
                     UNION
                     -- select all released fully awarded records from prism_pr_stage table and also same record (LSD) exists in delphi_po table
                     SELECT   *
                       FROM   PRISM_PR_STAGE PRS
                      WHERE   (PR_LINE_STATUS) = 'Fully Awarded'
                              AND contract_num = p_contract_num
                              AND ( (REQ_TYPE = 'REQUISITION'
                                     AND AWARD_DIST_OBLIG_AMT <> 0)
                                   OR (NVL (REQ_TYPE, 'REQFORMOD') =
                                          'REQFORMOD'))                 --7433
                              AND DO_NUMBER = '9999'
                              AND EXISTS
                                    (SELECT   1
                                       FROM   DELPHI_PO d
                                      WHERE   1 = 1
                                              AND prs.CONTRACT_NUM =
                                                    d.PO_NUMBER
                                              AND prs.AWARD_LI_NUM = d.LINE_NUM
                                              AND prs.SHIPMENT# =
                                                    d.SHIPMENT_NUMBER
                                              AND prs.DIST# =
                                                    d.DISTRIBUTION_NUM
                                              AND prs.do_number = d.release_num
                                              AND D.RELEASE_NUM = '9999')
                     /*select all released Item Active records from prism_pr_stage table and also same record (LSD) exists in delphi_po table and not exist
                                                                                                                                        in PRISM_PR table with fully awarded */
                     UNION
                     SELECT   *
                       FROM   PRISM_PR_STAGE prs
                      WHERE       1 = 1
                              AND DO_NUMBER = '9999'
                              AND (PR_LINE_STATUS) = 'Item Active'
                              AND contract_num = p_contract_num
                              AND EXISTS
                                    (SELECT   1
                                       FROM   DELPHI_PO d
                                      WHERE   1 = 1
                                              AND prs.CONTRACT_NUM =
                                                    d.PO_NUMBER
                                              AND prs.AWARD_LI_NUM = d.LINE_NUM
                                              AND prs.SHIPMENT# =
                                                    d.SHIPMENT_NUMBER
                                              AND prs.DIST# =
                                                    d.DISTRIBUTION_NUM
                                              AND d.RELEASE_NUM = '9999'
                                              AND NOT EXISTS
                                                    (SELECT   1
                                                       FROM   PRISM_PR pr
                                                      WHERE   1 = 1
                                                              AND pr.CONTRACT_NUM =
                                                                    d.PO_NUMBER
                                                              AND pr.AWARD_LI_NUM =
                                                                    d.LINE_NUM
                                                              AND pr.SHIPMENT# =
                                                                    d.SHIPMENT_NUMBER
                                                              AND pr.DIST# =
                                                                    d.DISTRIBUTION_NUM
                                                              AND PR.DO_NUMBER =
                                                                    '9999'
                                                              AND pr.AWARD_DIST_OBLIG_AMT =
                                                                    (d.QUANTITY_ORDERED
                                                                     - QUANTITY_CANCELLED)
                                                              AND PR_LINE_STATUS =
                                                                    'Fully Awarded'))
                     --ORDER BY  contract_num, do_number, award_li_num, shipment#,dist#,pr_li_num ;
                     UNION
                     /*select all non released Item Active records from prism_pr_stage table and also same record (LSD) exists in delphi_po table and not exist
                                                                    in PRISM_PR table with fully awarded */
                     SELECT   *
                       FROM   PRISM_PR_STAGE prs
                      WHERE       1 = 1
                              AND DO_NUMBER <> '9999'
                              AND PR_LINE_STATUS = 'Item Active'
                              AND contract_num = p_contract_num
                              AND EXISTS
                                    (SELECT   1
                                       FROM   DELPHI_PO d
                                      WHERE   1 = 1
                                              AND prs.CONTRACT_NUM =
                                                    d.PO_NUMBER
                                              -- AND prs.AWARD_LI_NUM = d.LINE_NUM
                                              AND prs.SHIPMENT# =
                                                    d.SHIPMENT_NUMBER
                                              AND prs.DIST# =
                                                    d.DISTRIBUTION_NUM
                                              AND prs.do_number = d.release_num
                                              AND NOT EXISTS
                                                    (SELECT   1
                                                       FROM   PRISM_PR pr
                                                      WHERE   1 = 1
                                                              AND pr.CONTRACT_NUM =
                                                                    d.PO_NUMBER
                                                              --  AND  pr.AWARD_LI_NUM     = d.LINE_NUM
                                                              AND pr.SHIPMENT# =
                                                                    d.SHIPMENT_NUMBER
                                                              AND pr.DIST# =
                                                                    d.DISTRIBUTION_NUM
                                                              AND pr.do_number =
                                                                    d.release_num
                                                              AND pr.AWARD_DIST_OBLIG_AMT =
                                                                    (d.QUANTITY_ORDERED
                                                                     - QUANTITY_CANCELLED)
                                                              AND pr.PR_LINE_STATUS =
                                                                    'Fully Awarded')))
                    A
         ORDER BY   contract_num,
                    do_number,
                    award_li_num,
                    shipment#,
                    dist#,
                    pr_li_num;
                    
        
      
   BEGIN
      SELECT   COUNT ( * )
        INTO   v_prism_pr_stage_cnt
        FROM   PRISM_PR_STAGE
       WHERE   contract_num = p_contract_num;

      SELECT   DISTINCT TRUNC (STAGE_DATE)
        INTO   v_prism_stage_date
        FROM   PRISM_PR_STAGE
       WHERE   contract_num = p_contract_num;

      SELECT   DISTINCT TRUNC (STAGE_DATE)
        INTO   v_delphi_stage_date
        FROM   DELPHI_PO_STAGE
       WHERE   po_number = p_contract_num;


      -- select count(*) into v_prism_pr_cnt from prism_pr;

      IF (v_prism_stage_Date) = TRUNC (SYSDATE)
         AND v_delphi_stage_date = TRUNC (SYSDATE)
      THEN
         -- Delete the data from prism_pr table before the table refresh.
         DELETE FROM   PRISM_PR
               WHERE   contract_num = p_contract_num;

         FOR PRISM_PR_STAGE_ROW IN C_PRISM_PR_STAGE
         LOOP
            -- inserting into prism_pr table from C_PRISM_PR_STAGE cursor
            INSERT INTO PRISM_PR (
                                     EXTRACT_DATE,
                                     PR,
                                     REQ_TYPE,
                                     PR_DESC,
                                     PR_LINEITEM_DESC,
                                     REQUISITIONER,
                                     REQUISITIONER_INFO,
                                     CONTRACT_NUM,
                                     PR_LI_NUM,
                                     PR_DIST_AMOUNT,
                                     AWARD_PROJECT#,
                                     AWARD_TASK#,
                                     AWARD_FUNDCODE,
                                     AWARD_BLI,
                                     AWARD_BUDGETYEAR,
                                     AWARD_OBJECT_CLASS,
                                     AWARD_BPAC,
                                     AWARD_EXPENDITUREORG,
                                     AWARD_EXPENDITURETYPE,
                                     AWARD_SGLACCT_CODE,
                                     AWARD_EXPENDITUREDATE,
                                     AWARD_ACCOUNT_CODE,
                                     AWARD_LI_NUM,
                                     SHIPMENT#,
                                     DIST#,
                                     NAME_POC,
                                     ORIGINATING_OFFICE,
                                     ORIGINATION_OFFICE_NAME,
                                     REQUISITION_DATE,
                                     CONSIGNEE_AND_DESTINATION,
                                     DATES_REQUIRED,
                                     CONTRACT_AUTHORITY_FURNISHED,
                                     TYPE_OF_FUNDS,
                                     EXPENDITURE_EXPIRATION_DATE,
                                     FUND_DESCRIPTION,
                                     PR_LINE_STATUS,
                                     AWARD_DIST_OBLIG_AMT,
                                     CONTRACT_MOD#,
                                     OBLIGATION_EXPIRATION_DATE,
                                     REQ_APPROVED_DATE,
                                     DO_NUMBER,
                                     AWARD_TYPE,
                                     PR_VERSION
                       )
              VALUES   (
                           SYSDATE,
                           PRISM_PR_STAGE_ROW.PR,
                           PRISM_PR_STAGE_ROW.REQ_TYPE,
                           PRISM_PR_STAGE_ROW.PR_DESC,
                           PRISM_PR_STAGE_ROW.PR_LINEITEM_DESC,
                           PRISM_PR_STAGE_ROW.REQUISITIONER,
                           PRISM_PR_STAGE_ROW.REQUISITIONER_INFO,
                           PRISM_PR_STAGE_ROW.CONTRACT_NUM,
                           PRISM_PR_STAGE_ROW.PR_LI_NUM,
                           DECODE (PRISM_PR_STAGE_ROW.REQ_TYPE,
                                   'REQUISITION',
                                   PRISM_PR_STAGE_ROW.PR_DIST_AMOUNT,
                                   PRISM_PR_STAGE_ROW.PR_DIST_COMMITTED_AMT),
                           PRISM_PR_STAGE_ROW.AWARD_PROJECT#,
                           PRISM_PR_STAGE_ROW.AWARD_TASK#,
                           PRISM_PR_STAGE_ROW.AWARD_FUNDCODE,
                           PRISM_PR_STAGE_ROW.AWARD_BLI,
                           PRISM_PR_STAGE_ROW.AWARD_BUDGETYEAR,
                           PRISM_PR_STAGE_ROW.AWARD_OBJECT_CLASS,
                           PRISM_PR_STAGE_ROW.AWARD_BPAC,
                           PRISM_PR_STAGE_ROW.AWARD_EXPENDITUREORG,
                           PRISM_PR_STAGE_ROW.AWARD_EXPENDITURETYPE,
                           PRISM_PR_STAGE_ROW.AWARD_SGLACCT_CODE,
                           PRISM_PR_STAGE_ROW.AWARD_EXPENDITUREDATE,
                           REPLACE (
                              PRISM_PR_STAGE_ROW.AWARD_ACCOUNT_CODE,
                              '.0000000000.0000000000.0000000000.0000000000'
                           ),
                           PRISM_PR_STAGE_ROW.AWARD_LI_NUM,
                           PRISM_PR_STAGE_ROW.shipment#,
                           PRISM_PR_STAGE_ROW.DIST#,
                           PRISM_PR_STAGE_ROW.NAME_POC,
                           PRISM_PR_STAGE_ROW.ORIGINATING_OFFICE,
                           PRISM_PR_STAGE_ROW.ORIGINATION_OFFICE_NAME,
                           PRISM_PR_STAGE_ROW.REQUISITION_DATE,
                           PRISM_PR_STAGE_ROW.CONSIGNEE_AND_DESTINATION,
                           PRISM_PR_STAGE_ROW.DATES_REQUIRED,
                           PRISM_PR_STAGE_ROW.CONTRACT_AUTHORITY_FURNISHED,
                           PRISM_PR_STAGE_ROW.TYPE_OF_FUNDS,
                           PRISM_PR_STAGE_ROW.EXPENDITURE_EXPIRATION_DATE,
                           PRISM_PR_STAGE_ROW.FUND_DESCRIPTION,
                           NVL (PRISM_PR_STAGE_ROW.PR_LINE_STATUS,
                                'Fully Awarded'),
                           PRISM_PR_STAGE_ROW.AWARD_DIST_OBLIG_AMT,
                           PRISM_PR_STAGE_ROW.CONTRACT_MOD#,
                           PRISM_PR_STAGE_ROW.OBLIGATION_EXPIRATION_DATE,
                           PRISM_PR_STAGE_ROW.REQ_APPROVED_DATE,
                           PRISM_PR_STAGE_ROW.DO_NUMBER,
                           PRISM_PR_STAGE_ROW.AWARD_TYPE,
                           PRISM_PR_STAGE_ROW.PR_VERSION
                       );
         END LOOP;


         -- added these update statement to update the admin-mod columns with 'N/A' Value for Sjawn's request


         UPDATE   prism_pr
            SET   PR = 'Adm-Mod-' || CONTRACT_MOD#,
                  REQ_TYPE = 'N/A',
                  PR_DESC = 'N/A',
                  PR_LINEITEM_DESC = 'N/A',
                  REQUISITIONER = 'N/A',
                  REQUISITIONER_INFO = 'N/A',
                  PR_LI_NUM = 'N/A',
                  --added on Sep 10th for admin PRs
                  PR_DIST_AMOUNT = award_dist_oblig_amt,
                  REQUISITION_DATE = '01/JAN/1800',
                  DATES_REQUIRED = 'N/A',
                  CONTRACT_AUTHORITY_FURNISHED = 'N/A',
                 -- EXPENDITURE_EXPIRATION_DATE = '01/JAN/1800',
                  FUND_DESCRIPTION = 'N/A',
                  PR_LINE_TOTAL_AMT = 0,
                  REQ_APPROVED_DATE = '01/JAN/1800'
          WHERE   pr IS NULL;
          
          
          

         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Success',
            'Successfully loaded prism data into PRISM_PR table for Fully awarded PRs for contract'
            || '  '
            || p_contract_num
         );
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Fail',
            'Failed to load prism_pr table from prism_pr_Stage for contract '
            || p_contract_num
            || '  '
            || 'Oracle Error msg '
            || SQLERRM
         );
         raise_application_error (
            -20003,
            'An error was encountered while inserting data from Prism stage to live table for contract '
            || p_contract_num
            || '  '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_MOVE_PRISM_STAGE_TO_LIVE;

   /******************************************************************************
                        NAME:       P_MOVE_DELPHI_LIVE_TO_ARCHIVE
      PURPOSE:    To archive data from delphi_po to delphi_po_archive table
      REVISIONS: 1.0
      Date:   1/29/2009
    ******************************************************************************/

   PROCEDURE P_MOVE_DELPHI_LIVE_TO_ARCHIVE (p_contract_num varchar2)
   IS
      -- Selecting the prism_pr data

      v_err_1             varchar2 (300) := NULL;

      CURSOR C_DELPHI_PO
      IS
         SELECT   *
           FROM   DELPHI_PO
          WHERE   1 = 1 AND po_number = p_contract_num
                  AND EXISTS
                        (SELECT   1
                           FROM   DELPHI_PO_STAGE
                          WHERE       1 = 1
                                  AND po_number = p_contract_num
                                  AND TRUNC (stage_date) = TRUNC (SYSDATE));

      v_delphi_stage_dt   date;
   BEGIN
      SELECT   DISTINCT TRUNC (stage_Date)
        INTO   v_delphi_stage_dt
        FROM   delphi_po_stage
       WHERE   po_number = p_contract_num;

      IF (v_delphi_stage_dt) = TRUNC (SYSDATE)
      THEN
         -- Delete the delphi_po_archive table with the archive_date as sysdate before archiving the data to make sure that we dont' override.
         DELETE FROM   DELPHI_PO_ARCHIVE
               WHERE   TRUNC (ARCHIVE_DATE) = TRUNC (SYSDATE)
                       AND po_number = p_contract_num;


         FOR DELPHI_PO_ROW IN C_DELPHI_PO
         LOOP
            -- inserting the data into delphi_po_archive from delphi_po_row cursor
            INSERT INTO DELPHI_PO_ARCHIVE
              VALUES   (SYSDATE,
                        DELPHI_PO_ROW.EXTRACT_DATE,
                        DELPHI_PO_ROW.PO_NUMBER,
                        DELPHI_PO_ROW.VENDOR_NAME,
                        DELPHI_PO_ROW.VENDOR_SITE_CODE,
                        DELPHI_PO_ROW.RELEASE_NUM,
                        DELPHI_PO_ROW.LINE_ITEM,
                        DELPHI_PO_ROW.MATCHING_TYPE,
                        DELPHI_PO_ROW.QUANTITY_ORDERED,
                        DELPHI_PO_ROW.QUANTITY_BILLED,
                        DELPHI_PO_ROW.QUANTITY_RECEIVED,
                        DELPHI_PO_ROW.QUANTITY_CANCELLED,
                        DELPHI_PO_ROW.OBLIGATED_BALANCE,
                        DELPHI_PO_ROW.PROJECT_NUMBER,
                        DELPHI_PO_ROW.TASK_NUMBER,
                        DELPHI_PO_ROW.CHARGE_ACCOUNT,
                        DELPHI_PO_ROW.MULTIPLIER,
                        DELPHI_PO_ROW.FUND,
                        DELPHI_PO_ROW.BUDYEAR,
                        DELPHI_PO_ROW.BPAC,
                        DELPHI_PO_ROW.ORGCODE,
                        DELPHI_PO_ROW.OBJECT_CLASS,
                        DELPHI_PO_ROW.ACCOUNT,
                        DELPHI_PO_ROW.LINE_NUM,
                        DELPHI_PO_ROW.SHIPMENT_NUMBER,
                        DELPHI_PO_ROW.DISTRIBUTION_NUM,
                        DELPHI_PO_ROW.NET_QTY_ORDERED);
         END LOOP;

         -- calling the job event detail procedure to capture the messages
         P_JOB_EVENT_DETAIL (
            'DELPHI PO',
            'Success',
            'Successfully loaded DELPHI data into DELPHI_PO_ARCHIVE table for contract '
            || p_contract_num
         );
      ELSE
         ROLLBACK;
         v_err_1 :=
            'since Delphi Stage table state date is not matching with the system run date';
         --P_JOB_EVENT_DETAIL('PRISM PR','Fail','Failed to load date from prism_pr to prism_pr_archive table '||v_err);
         raise_application_error (-20040, 'Application Error');
      END IF;
   -- deleting the data from DELPHI_PO_ARCHIVE table if the archive_Date is more then 2 years.
   --DELETE FROM DELPHI_PO_ARCHIVE
   --WHERE TRUNC(ARCHIVE_DATE) <= ADD_MONTHS(TRUNC(SYSDATE),-24);
   --COMMIT;


   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         -- calling the job even detail procedure to capture the job even details for error messages
         P_JOB_EVENT_DETAIL (
            'DELPHI PO',
            'Fail',
            'Failed to load date from delphi_po to delphi_po_archive table  for contract '
            || p_contract_num
            || v_err_1
            || ' Oracle Error msg '
            || SQLERRM
         );
         raise_application_error (
            -20041,
            'An error was encountered while moving data from delphi_po to delphi_po_Archive table- '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_MOVE_DELPHI_LIVE_TO_ARCHIVE;

   /******************************************************************************
                        NAME:       P_MOVE_DELPHI_STAGE_TO_LIVE
      PURPOSE:    To populate data from delphi_po_stage to delphi_po live table
      REVISIONS: 1.0
      Date:   1/29/2009
    ******************************************************************************/
   PROCEDURE P_MOVE_DELPHI_STAGE_TO_LIVE (p_contract_num varchar2)
   IS
      v_delphi_po_stage_cnt   number;
      v_delphi_stage_date     date;
      v_prism_stage_date      date;

      -- collecting the data from delphi_po_stage table in C_DELPHI_PO_STAGE cursor for given contract number.
      CURSOR C_DELPHI_PO_STAGE
      IS
         SELECT   STAGE_DATE,
                  PO_NUMBER,
                  VENDOR_NAME,
                  VENDOR_SITE_CODE,
                  NVL (RELEASE_NUM, '9999') RELEASE_NUM,
                  LINE_ITEM,
                  MATCHING_TYPE,
                  QUANTITY_ORDERED,
                  QUANTITY_BILLED,
                  QUANTITY_RECEIVED,
                  QUANTITY_CANCELLED,
                  OBLIGATED_BALANCE,
                  PROJECT_NUMBER,
                  TASK_NUMBER,
                  CHARGE_ACCOUNT,
                  TO_NUMBER (MULTIPLIER) MULTIPLIER,
                  FUND,
                  BUDYEAR,
                  BPAC,
                  ORGCODE,
                  OBJECT_CLASS,
                  ACCOUNT,
                  LINE_NUM,
                  SHIPMENT_NUMBER,
                  DISTRIBUTION_NUM,
                  NET_QTY_ORDERED
           FROM   DELPHI_PO_STAGE
          WHERE   po_number = p_contract_num;
   /* cursor c_update_prism_pr is
                select po_number,line_num, shipment_number, mod(distribution_num,200) dist_mod, distribution_num
    from delphi_po
    where distribution_num >200
    order by line_num, shipment_number, distribution_num;
   */



   BEGIN
      --SELECT COUNT(*) INTO v_delphi_po_stage_cnt FROM DELPHI_PO_STAGE where po_number =p_contract_num;

      SELECT   DISTINCT TRUNC (STAGE_DATE)
        INTO   v_delphi_stage_date
        FROM   DELPHI_PO_STAGE
       WHERE   po_number = p_contract_num;

      SELECT   DISTINCT TRUNC (STAGE_DATE)
        INTO   v_prism_stage_date
        FROM   PRISM_PR_STAGE
       WHERE   contract_num = p_contract_num;


      --select count(*) into v_delphi_po_cnt from prism_pr;

      -- Verifying the PRISM & DELPHI stage dates  to make sure the dates are equal to the sysdate before moving into DELPHI_PO  table.
      IF TRUNC (v_delphi_stage_date) = TRUNC (SYSDATE)
         AND TRUNC (v_prism_stage_date) = TRUNC (SYSDATE)
      THEN
         -- ADDED TO AVOID DISTRIBUTION 123 WIHT NET QTY ORDERED AS 0.01 CENT  ON aPR 21ST 2014
         DELETE FROM   DELPHI_PO_STAGE
               WHERE   po_number = p_contract_num
                       AND (    line_num = 2875
                            AND distribution_num = 123
                            AND net_qty_ordered = 0.01);


         -- delete the data from DELPHI_PO table for given contract
         DELETE FROM   DELPHI_PO
               WHERE   po_number = p_contract_num;

         --commit;

         FOR DELPHI_PO_STAGE_ROW IN C_DELPHI_PO_STAGE
         LOOP
            -- inserting the data from delphi_po table from C_DELPHI_PO_STAGE cursor
            INSERT INTO DELPHI_PO (Extract_Date,
                                   PO_NUMBER,
                                   VENDOR_NAME,
                                   VENDOR_SITE_CODE,
                                   RELEASE_NUM,
                                   LINE_ITEM,
                                   MATCHING_TYPE,
                                   QUANTITY_ORDERED,
                                   QUANTITY_BILLED,
                                   QUANTITY_RECEIVED,
                                   QUANTITY_CANCELLED,
                                   OBLIGATED_BALANCE,
                                   PROJECT_NUMBER,
                                   TASK_NUMBER,
                                   CHARGE_ACCOUNT,
                                   MULTIPLIER,
                                   FUND,
                                   BUDYEAR,
                                   BPAC,
                                   ORGCODE,
                                   OBJECT_CLASS,
                                   ACCOUNT,
                                   LINE_NUM,
                                   SHIPMENT_NUMBER,
                                   DISTRIBUTION_NUM,
                                   NET_QTY_ORDERED)
              VALUES   (SYSDATE,
                        DELPHI_PO_STAGE_ROW.PO_NUMBER,
                        DELPHI_PO_STAGE_ROW.VENDOR_NAME,
                        DELPHI_PO_STAGE_ROW.VENDOR_SITE_CODE,
                        DELPHI_PO_STAGE_ROW.RELEASE_NUM,
                        DELPHI_PO_STAGE_ROW.LINE_ITEM,
                        DELPHI_PO_STAGE_ROW.MATCHING_TYPE,
                        DELPHI_PO_STAGE_ROW.QUANTITY_ORDERED,
                        DELPHI_PO_STAGE_ROW.QUANTITY_BILLED,
                        DELPHI_PO_STAGE_ROW.QUANTITY_RECEIVED,
                        DELPHI_PO_STAGE_ROW.QUANTITY_CANCELLED,
                        DELPHI_PO_STAGE_ROW.OBLIGATED_BALANCE,
                        DELPHI_PO_STAGE_ROW.PROJECT_NUMBER,
                        DELPHI_PO_STAGE_ROW.TASK_NUMBER,
                        DELPHI_PO_STAGE_ROW.CHARGE_ACCOUNT,
                        DELPHI_PO_STAGE_ROW.MULTIPLIER,
                        DELPHI_PO_STAGE_ROW.FUND,
                        DELPHI_PO_STAGE_ROW.BUDYEAR,
                        DELPHI_PO_STAGE_ROW.BPAC,
                        DELPHI_PO_STAGE_ROW.ORGCODE,
                        DELPHI_PO_STAGE_ROW.OBJECT_CLASS,
                        DELPHI_PO_STAGE_ROW.ACCOUNT,
                        DELPHI_PO_STAGE_ROW.LINE_NUM,
                        DELPHI_PO_STAGE_ROW.SHIPMENT_NUMBER,
                        (DELPHI_PO_STAGE_ROW.DISTRIBUTION_NUM),
                        DELPHI_PO_STAGE_ROW.NET_QTY_ORDERED);
         END LOOP;


         /*  for row_update_prism_pr in c_update_prism_pr loop
                                    update prism_pr
            set dist#          = row_update_prism_pr.distribution_num
            where contract_num = row_update_prism_pr.po_number
            and award_li_num   = row_update_prism_pr.line_num
            and shipment#      = row_update_prism_pr.shipment_number
            and mod(dist#,100) = row_update_prism_pr.dist_mod;
           end loop;
         */
         -- calling the job event detail procedure to capture the error messages.
         P_JOB_EVENT_DETAIL (
            'DELPHI PO',
            'Success',
            'Successfully loaded delphi data into DELPHI_PO table for contract '
            || p_contract_num
         );
      -- updating the kitt_agency_info table wiht delphi_po_update_date and delphi_po_updated_by info
      /*UPDATE KITT_AGENCY_INFO
                  SET DELPHI_PO_UPDATE_DATE = (SELECT MAX(EXTRACT_DATE)
                                   FROM DELPHI_PO where ),
          DELPHI_PO_UPDATED_BY ='Chandra',
          DELPHI_PO_NUM        =(SELECT COUNT(*) FROM DELPHI_PO);
     P_JOB_EVENT_DETAIL('DELPHI PO','Success','Successfully updated delphi related columns in KITT_AGENCY_INFO table for contract');
    */
      END IF;
   -- COMMIT;

   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'DELPHI PO',
            'Fail',
            'Failed to load delphi_po table from delphi_po_stage  for contract '
            || p_contract_num
            || '  '
            || 'Oracle Error msg '
            || SQLERRM
         );
         raise_application_error (
            -20005,
            'An error was encountered while inserting data from Delphi_po_stage to delphi_po live table - '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_MOVE_DELPHI_STAGE_TO_LIVE;

   /******************************************************************************
            NAME:       P_MOVE_PRISM_PR_DELPHI_PO
      PURPOSE:    To populate data into prism_pr_delphi_po table from prism_pr and
                  delphi_po.
      REVISIONS: 1.0
      Date:   1/29/2009
    ******************************************************************************/

   PROCEDURE P_MOVE_PRISM_PR_DELPHI_PO (p_contract_num varchar2)
   IS
      v_prism_stage_dt    date;
      v_delphi_stage_dt   date;

      -- SELECT THE DATA FROM PRISM_PR_STAGE TABLE
      CURSOR C1
      IS
           SELECT   *
             FROM   PRISM_PR
            WHERE   1 = 1 AND contract_num = p_contract_num
         ORDER BY   do_number,
                    award_li_num,
                    shipment#,
                    dist#,
                    pr_li_num,
                    contract_mod#;

      CURSOR C_UPDATE_CONTRACT_MOD_TOT
      IS
           SELECT   contract_num,
                    DO_NUMBER,
                    CONTRACT_MOD#,
                    SUM (NET_QTY_ORDERED) CONTRACT_MOD_SUBTOTAL
             FROM   PRISM_PR_DELPHI_PO
            WHERE   po_number = p_contract_num
         GROUP BY   CONTRACT_NUM, DO_NUMBER, CONTRACT_MOD#;
   BEGIN
      SELECT   DISTINCT TRUNC (STAGE_DATE)
        INTO   v_prism_stage_dt
        FROM   PRISM_PR_STAGE
       WHERE   contract_num = P_contract_num;


      SELECT   DISTINCT TRUNC (STAGE_DATE)
        INTO   v_delphi_stage_dt
        FROM   DELPHI_PO_STAGE
       WHERE   po_number = P_contract_num;

      IF v_prism_stage_dt = TRUNC (SYSDATE)
         AND v_delphi_stage_dt = TRUNC (SYSDATE)
      THEN
         DELETE FROM   PRISM_PR_DELPHI_PO
               WHERE   po_number = P_contract_num;


         -- INSERT THE PRISM_PR_DELHI_PO TABLE  FROM DELPHI_PO TABLE FOR DELPHI_PO INFORMATION ONLY
         INSERT INTO PRISM_PR_DELPHI_PO (D_EXTRACT_DATE,
                                         PO_NUMBER,
                                         VENDOR_NAME,
                                         VENDOR_SITE_CODE,
                                         RELEASE_NUM,
                                         LINE_ITEM,
                                         MATCHING_TYPE,
                                         QUANTITY_ORDERED,
                                         QUANTITY_BILLED,
                                         QUANTITY_RECEIVED,
                                         QUANTITY_CANCELLED,
                                         OBLIGATED_BALANCE,
                                         PROJECT_NUMBER,
                                         TASK_NUMBER,
                                         CHARGE_ACCOUNT,
                                         MULTIPLIER,
                                         FUND,
                                         BUDYEAR,
                                         BPAC,
                                         ORGCODE,
                                         OBJECT_CLASS,
                                         ACCOUNT,
                                         LINE_NUM,
                                         SHIPMENT_NUMBER,
                                         DISTRIBUTION_NUM,
                                         NET_QTY_ORDERED)
            SELECT   EXTRACT_DATE,
                     PO_NUMBER,
                     VENDOR_NAME,
                     VENDOR_SITE_CODE,
                     RELEASE_NUM,
                     LINE_ITEM,
                     MATCHING_TYPE,
                     QUANTITY_ORDERED,
                     QUANTITY_BILLED,
                     QUANTITY_RECEIVED,
                     QUANTITY_CANCELLED,
                     OBLIGATED_BALANCE,
                     PROJECT_NUMBER,
                     TASK_NUMBER,
                     CHARGE_ACCOUNT,
                     MULTIPLIER,
                     FUND,
                     BUDYEAR,
                     BPAC,
                     ORGCODE,
                     OBJECT_CLASS,
                     ACCOUNT,
                     LINE_NUM,
                     SHIPMENT_NUMBER,
                     DISTRIBUTION_NUM,
                     NET_QTY_ORDERED
              FROM   DELPHI_PO
             WHERE   po_number = p_contract_num;

         --P_job_detail('Successfully loaded the PRISM_PR_DELPHI_PO table with DELPHI related columns from DELPHI_PO table');

         --P_job_event_detail('PRISM PR DELPHI PO','Success','Successfully loaded the delphi data  in prism_pr_delphi_po table for conract  '|| p_contract_num|| '  '|| 'Oracle Error msg '|| SQLERRM);

         -- OPENING THE LOOP TO FETCH THE PRISM_PR DATA AND UPDATE INTO PRISM_PR_DELPHI_PO TABLE FOR PRISM RELATED INFORMATION
         FOR C_REC IN C1
         LOOP
            -- begin

            IF C_REC.DO_NUMBER = '9999'
            THEN
               BEGIN
                  -- Upating the prism_pr_delphi_po   table with prism_pr information for fully awarded contracts
                  UPDATE   PRISM_PR_DELPHI_PO pd
                     SET   EXTRACT_DATE = SYSDATE,
                           PR = C_REC.PR,
                           REQ_TYPE = C_REC.REQ_TYPE,
                           PR_DESC = C_REC.PR_DESC,
                           PR_LINEITEM_DESC = C_REC.PR_LINEITEM_DESC,
                           REQUISITIONER = C_REC.REQUISITIONER,
                           CONTRACT_NUM = C_REC.CONTRACT_NUM,
                           PR_LI_NUM = C_REC.PR_LI_NUM,
                           PR_DIST_AMOUNT = C_REC.PR_DIST_AMOUNT,
                           AWARD_PROJECT# = C_REC.AWARD_PROJECT#,
                           AWARD_TASK# = C_REC.AWARD_TASK#,
                           AWARD_FUNDCODE = C_REC.AWARD_FUNDCODE,
                           AWARD_BLI = C_REC.AWARD_BLI,
                           AWARD_BUDGETYEAR = C_REC.AWARD_BUDGETYEAR,
                           AWARD_OBJECT_CLASS = C_REC.AWARD_OBJECT_CLASS,
                           AWARD_BPAC = C_REC.AWARD_BPAC,
                           AWARD_EXPENDITUREORG = C_REC.AWARD_EXPENDITUREORG,
                           AWARD_EXPENDITURETYPE = C_REC.AWARD_EXPENDITURETYPE,
                           AWARD_SGLACCT_CODE = C_REC.AWARD_SGLACCT_CODE,
                           AWARD_EXPENDITUREDATE = C_REC.AWARD_EXPENDITUREDATE,
                           -- AWARD_ACCOUNT_CODE      = replace(C_REC.award_account_code, '.0000000000.0000000000.0000000000.0000000000'),
                           AWARD_ACCOUNT_CODE = C_REC.award_account_code,
                           AWARD_LI_NUM = C_REC.AWARD_LI_NUM,
                           shipment# = C_REC.shipment#,
                           DIST# = C_REC.DIST#,
                           NAME_POC = C_REC.NAME_POC,
                           ORIGINATING_OFFICE_DATA =
                                 C_REC.ORIGINATING_OFFICE
                              || '/'
                              || C_REC.ORIGINATION_OFFICE_NAME,
                           --  ORIGINATION_OFFICE_NAME      = C_REC.ORIGINATION_OFFICE_NAME,
                           --  REQUISITIONER_INFO           = C_REC.REQUISITIONER_INF
                           REQUISITION_DATE = C_REC.REQUISITION_DATE,
                           CONSIGNEE_AND_DESTINATION =
                              C_REC.CONSIGNEE_AND_DESTINATION,
                           DATES_REQUIRED = C_REC.DATES_REQUIRED,
                           CONTRACT_AUTHORITY_FURNISHED =
                              C_REC.CONTRACT_AUTHORITY_FURNISHED,
                           TYPE_OF_FUNDS = C_REC.TYPE_OF_FUNDS,
                           EXPENDITURE_EXPIRATION_DATE =
                              C_REC.EXPENDITURE_EXPIRATION_DATE,
                           FUND_DESCRIPTION = C_REC.FUND_DESCRIPTION,
                           CONTRACT_MOD# = C_REC.CONTRACT_MOD#,
                           DO_NUMBER = C_REC.DO_NUMBER,
                           AWARD_TYPE = C_REC.AWARD_TYPE
                   WHERE       1 = 1
                           --and pd.charge_account = replace(C_REC.award_account_code,'.0000000000.0000000000.0000000000.0000000000')
                           -- AND pd.CHARGE_ACCOUNT             = C_REC.AWARD_ACCOUNT_CODE
                           AND (pd.DISTRIBUTION_NUM) = C_REC.DIST#
                           AND pd.SHIPMENT_NUMBER = C_REC.SHIPMENT#
                           AND pd.LINE_NUM = TO_NUMBER (C_REC.AWARD_LI_NUM)
                           --and pd.RELEASE_NUM                = C_REC.DO_NUMBER
                           AND pd.PO_NUMBER = C_REC.CONTRACT_NUM;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     ROLLBACK;
                     P_job_event_detail (
                        'PRISM PR DELPHI PO',
                        'Fail',
                        'Failed to update prism non released data in prism_pr_delphi_po table for contract  '
                        || p_contract_num
                        || '  '
                        || 'Oracle Error msg '
                        || SQLERRM
                     );
                     raise_application_error (
                        -20019,
                        'An error was encountered while update prism data in prism_pr_delphi_po table - '
                        || SQLCODE
                        || ' -ERROR- '
                        || SQLERRM
                     );
               END;
            -- and pd.do_number = c_rec.do_number;

            ELSE
               BEGIN
                  -- Upating the prism_pr_delphi_po   table with prism_pr information for fully awarded contracts
                  UPDATE   PRISM_PR_DELPHI_PO pd
                     SET   EXTRACT_DATE = SYSDATE,
                           PR = C_REC.PR,
                           REQ_TYPE = C_REC.REQ_TYPE,
                           PR_DESC = C_REC.PR_DESC,
                           PR_LINEITEM_DESC = C_REC.PR_LINEITEM_DESC,
                           REQUISITIONER = C_REC.REQUISITIONER,
                           CONTRACT_NUM = C_REC.CONTRACT_NUM,
                           PR_LI_NUM = C_REC.PR_LI_NUM,
                           PR_DIST_AMOUNT = C_REC.PR_DIST_AMOUNT,
                           AWARD_PROJECT# = C_REC.AWARD_PROJECT#,
                           AWARD_TASK# = C_REC.AWARD_TASK#,
                           AWARD_FUNDCODE = C_REC.AWARD_FUNDCODE,
                           AWARD_BLI = C_REC.AWARD_BLI,
                           AWARD_BUDGETYEAR = C_REC.AWARD_BUDGETYEAR,
                           AWARD_OBJECT_CLASS = C_REC.AWARD_OBJECT_CLASS,
                           AWARD_BPAC = C_REC.AWARD_BPAC,
                           AWARD_EXPENDITUREORG = C_REC.AWARD_EXPENDITUREORG,
                           AWARD_EXPENDITURETYPE = C_REC.AWARD_EXPENDITURETYPE,
                           AWARD_SGLACCT_CODE = C_REC.AWARD_SGLACCT_CODE,
                           AWARD_EXPENDITUREDATE = C_REC.AWARD_EXPENDITUREDATE,
                           -- AWARD_ACCOUNT_CODE      = replace(C_REC.award_account_code, '.0000000000.0000000000.0000000000.0000000000'),
                           AWARD_ACCOUNT_CODE = C_REC.award_account_code,
                           AWARD_LI_NUM = C_REC.AWARD_LI_NUM,
                           shipment# = C_REC.shipment#,
                           DIST# = C_REC.DIST#,
                           NAME_POC = C_REC.NAME_POC,
                           ORIGINATING_OFFICE_DATA =
                                 C_REC.ORIGINATING_OFFICE
                              || '/'
                              || C_REC.ORIGINATION_OFFICE_NAME,
                           --  ORIGINATION_OFFICE_NAME      = C_REC.ORIGINATION_OFFICE_NAME,
                           --  REQUISITIONER_INFO           = C_REC.REQUISITIONER_INF
                           REQUISITION_DATE = C_REC.REQUISITION_DATE,
                           CONSIGNEE_AND_DESTINATION =
                              C_REC.CONSIGNEE_AND_DESTINATION,
                           DATES_REQUIRED = C_REC.DATES_REQUIRED,
                           CONTRACT_AUTHORITY_FURNISHED =
                              C_REC.CONTRACT_AUTHORITY_FURNISHED,
                           TYPE_OF_FUNDS = C_REC.TYPE_OF_FUNDS,
                           EXPENDITURE_EXPIRATION_DATE =
                              C_REC.EXPENDITURE_EXPIRATION_DATE,
                           FUND_DESCRIPTION = C_REC.FUND_DESCRIPTION,
                           CONTRACT_MOD# = C_REC.CONTRACT_MOD#,
                           DO_NUMBER = C_REC.DO_NUMBER,
                           AWARD_TYPE = C_REC.AWARD_TYPE
                   WHERE       1 = 1
                           --and pd.charge_account = replace(C_REC.award_account_code,'.0000000000.0000000000.0000000000.0000000000')
                           -- AND pd.CHARGE_ACCOUNT             = C_REC.AWARD_ACCOUNT_CODE
                           AND (pd.DISTRIBUTION_NUM) = C_REC.DIST#
                           AND pd.SHIPMENT_NUMBER = C_REC.SHIPMENT#
                           AND pd.LINE_ITEM = TO_NUMBER (C_REC.AWARD_LI_NUM)
                           AND pd.RELEASE_NUM = C_REC.DO_NUMBER
                           AND pd.PO_NUMBER = C_REC.CONTRACT_NUM;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     ROLLBACK;
                     P_job_event_detail (
                        'PRISM PR DELPHI PO',
                        'Fail',
                        'Failed to update prism released data in prism_pr_delphi_po table for contract  '
                        || p_contract_num
                        || '  '
                        || 'Oracle Error msg '
                        || SQLERRM
                     );
                     raise_application_error (
                        -20019,
                        'An error was encountered while update prism data in prism_pr_delphi_po table - '
                        || SQLCODE
                        || ' -ERROR- '
                        || SQLERRM
                     );
               END;
            END IF;
         END LOOP;

         P_JOB_EVENT_DETAIL (
            'PRISM PR DELPHI PO',
            'Success',
            'Successfully loaded prism & delphi data in prism_pr_delphi_po table for contract '
            || p_contract_num
         );
      END IF;

      FOR UPDATE_CONTRACT_MOD_TOT_ROW IN C_UPDATE_CONTRACT_MOD_TOT
      LOOP
         BEGIN
            -- updating the contract_mod_subtotal based on contract number and contract mod#.in prism_pr_delphi_po table
            UPDATE   PRISM_PR_DELPHI_PO
               SET   CONTRACT_MOD_SUBTOTAL =
                        UPDATE_CONTRACT_MOD_TOT_ROW.CONTRACT_MOD_SUBTOTAL
             WHERE   po_number = UPDATE_CONTRACT_MOD_TOT_ROW.CONTRACT_NUM
                     --AND NVL(DO_NUMBER,'9999')=NVL(UPDATE_CONTRACT_MOD_TOT_ROW.DO_NUMBER,'9999')
                     AND CONTRACT_MOD# =
                           UPDATE_CONTRACT_MOD_TOT_ROW.CONTRACT_MOD#;
         EXCEPTION
            WHEN OTHERS
            THEN
               ROLLBACK;
               P_job_event_detail (
                  'PRISM PR DELPHI PO',
                  'Fail',
                  'Failed to update contract_mod_subtotal column in prism_pr_delphi_po table for conract  '
                  || p_contract_num
                  || '  '
                  || 'Oracle Error msg '
                  || SQLERRM
               );
               raise_application_error (
                  -20019,
                  'An error was encountered while update contract_mod_subtotal in prism_pr_delphi_po table - '
                  || SQLCODE
                  || ' -ERROR- '
                  || SQLERRM
               );
         END;
      END LOOP;
   -- COMMIT;

   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_job_event_detail (
            'PRISM PR DELPHI PO',
            'Fail',
            'Failed to load prism and delphi data in prism_pr_delphi_po table for conract '
            || p_contract_num
            || '  '
            || 'Oracle Error msg '
            || SQLERRM
         );
         raise_application_error (
            -20009,
            'An error was encountered while movign prism and delphi data in prism_pr_delphi_po table - '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_MOVE_PRISM_PR_DELPHI_PO;

   /******************************************************************************
           NAME:      P_MOVE_PRISM_LIVE_TO_ARCHIVE
     PURPOSE:   Procedure to archive PRISM PR data.
     REVISIONS: 1.0
     Date:   1/29/2009
   ******************************************************************************/

   PROCEDURE P_MOVE_PRISM_DELPHI_LIVE_TO_AR
   IS
      -- Selecting the prism_pr data
      CURSOR C_PRISM_PR_DEL_PO
      IS
         SELECT   * FROM prism_pr_delphi_po;
   --      where exists
   --        (select 1
   --         from prism_pr_stage
   --         where trunc(stage_date) = trunc(sysdate))
   --       and exists
   --        (select 1
   --         from delphi_po_stage
   --         where trunc(stage_date) = trunc(sysdate));


   BEGIN
      -- Deleting the data from prism_pr_delphi_po_archive table before loading the data from prism_pr_delphi_po table
      DELETE FROM   prism_pr_delphi_po_archive;

      FOR PRISM_PR_DEL_PO_ROW IN C_PRISM_PR_DEL_PO
      LOOP
         -- inserting data from prism pr to prism pr archive table
         INSERT INTO prism_pr_delphi_po_archive
           VALUES   (SYSDATE,
                     PRISM_PR_DEL_PO_ROW.EXTRACT_DATE,
                     PRISM_PR_DEL_PO_ROW.PR,
                     PRISM_PR_DEL_PO_ROW.REQ_TYPE,
                     PRISM_PR_DEL_PO_ROW.PR_DESC,
                     PRISM_PR_DEL_PO_ROW.PR_LINEITEM_DESC,
                     PRISM_PR_DEL_PO_ROW.REQUISITIONER,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_NUM,
                     PRISM_PR_DEL_PO_ROW.PR_LI_NUM,
                     PRISM_PR_DEL_PO_ROW.PR_DIST_AMOUNT,
                     PRISM_PR_DEL_PO_ROW.AWARD_PROJECT#,
                     PRISM_PR_DEL_PO_ROW.AWARD_TASK#,
                     PRISM_PR_DEL_PO_ROW.AWARD_FUNDCODE,
                     PRISM_PR_DEL_PO_ROW.AWARD_BLI,
                     PRISM_PR_DEL_PO_ROW.AWARD_BUDGETYEAR,
                     PRISM_PR_DEL_PO_ROW.AWARD_OBJECT_CLASS,
                     PRISM_PR_DEL_PO_ROW.AWARD_BPAC,
                     PRISM_PR_DEL_PO_ROW.AWARD_EXPENDITUREORG,
                     PRISM_PR_DEL_PO_ROW.AWARD_EXPENDITURETYPE,
                     PRISM_PR_DEL_PO_ROW.AWARD_SGLACCT_CODE,
                     PRISM_PR_DEL_PO_ROW.AWARD_EXPENDITUREDATE,
                     PRISM_PR_DEL_PO_ROW.AWARD_ACCOUNT_CODE,
                     PRISM_PR_DEL_PO_ROW.AWARD_LI_NUM,
                     PRISM_PR_DEL_PO_ROW.SHIPMENT#,
                     PRISM_PR_DEL_PO_ROW.DIST#,
                     PRISM_PR_DEL_PO_ROW.NAME_POC,
                     PRISM_PR_DEL_PO_ROW.ORIGINATING_OFFICE_DATA,
                     PRISM_PR_DEL_PO_ROW.REQUISITION_DATE,
                     PRISM_PR_DEL_PO_ROW.CONSIGNEE_AND_DESTINATION,
                     PRISM_PR_DEL_PO_ROW.DATES_REQUIRED,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_AUTHORITY_FURNISHED,
                     PRISM_PR_DEL_PO_ROW.TYPE_OF_FUNDS,
                     PRISM_PR_DEL_PO_ROW.EXPENDITURE_EXPIRATION_DATE,
                     PRISM_PR_DEL_PO_ROW.FUND_DESCRIPTION,
                     PRISM_PR_DEL_PO_ROW.D_EXTRACT_DATE,
                     PRISM_PR_DEL_PO_ROW.PO_NUMBER,
                     PRISM_PR_DEL_PO_ROW.VENDOR_NAME,
                     PRISM_PR_DEL_PO_ROW.VENDOR_SITE_CODE,
                     PRISM_PR_DEL_PO_ROW.RELEASE_NUM,
                     PRISM_PR_DEL_PO_ROW.LINE_ITEM,
                     PRISM_PR_DEL_PO_ROW.MATCHING_TYPE,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_ORDERED,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_BILLED,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_RECEIVED,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_CANCELLED,
                     PRISM_PR_DEL_PO_ROW.OBLIGATED_BALANCE,
                     PRISM_PR_DEL_PO_ROW.PROJECT_NUMBER,
                     PRISM_PR_DEL_PO_ROW.TASK_NUMBER,
                     PRISM_PR_DEL_PO_ROW.CHARGE_ACCOUNT,
                     PRISM_PR_DEL_PO_ROW.MULTIPLIER,
                     PRISM_PR_DEL_PO_ROW.FUND,
                     PRISM_PR_DEL_PO_ROW.BUDYEAR,
                     PRISM_PR_DEL_PO_ROW.BPAC,
                     PRISM_PR_DEL_PO_ROW.ORGCODE,
                     PRISM_PR_DEL_PO_ROW.OBJECT_CLASS,
                     PRISM_PR_DEL_PO_ROW.ACCOUNT,
                     PRISM_PR_DEL_PO_ROW.LINE_NUM,
                     PRISM_PR_DEL_PO_ROW.SHIPMENT_NUMBER,
                     PRISM_PR_DEL_PO_ROW.DISTRIBUTION_NUM,
                     PRISM_PR_DEL_PO_ROW.NET_QTY_ORDERED,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_MOD#,
                     PRISM_PR_DEL_PO_ROW.RECORD_TYPE,
                     PRISM_PR_DEL_PO_ROW.C_HOLD,
                     PRISM_PR_DEL_PO_ROW.C_DELETE,
                     PRISM_PR_DEL_PO_ROW.C_SEND_TO_KITT,
                     PRISM_PR_DEL_PO_ROW.C_CORE,
                     PRISM_PR_DEL_PO_ROW.C_DEOBLIGATE,
                     PRISM_PR_DEL_PO_ROW.C_EXEMPT,
                     PRISM_PR_DEL_PO_ROW.ACTION_TAKEN_DATE,
                     PRISM_PR_DEL_PO_ROW.PMO_NOTIFIED_FLAG,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_MOD_SUBTOTAL,
                     PRISM_PR_DEL_PO_ROW.DO_NUMBER,
                     PRISM_PR_DEL_PO_ROW.AWARD_TYPE);
      END LOOP;

      -- calling job detail procedure to update the job detail information
      P_JOB_EVENT_DETAIL (
         'PRISM PR DELPHI PO',
         'Success',
         'Successfully Loaded PRISM_PR_DELPHI_PO DATA INTO PRISM_PR_DELPHI_PO_ARCHIVE Table'
      );
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Fail',
            'Failed to load date from prism_pr to prism_pr_delphi_po_archive table'
            || '  '
            || 'Oracle Error msg'
            || SQLERRM
         );
         raise_application_error (
            -20021,
            'An error was encountered while moving data from Prism live to Archive table- '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_MOVE_PRISM_DELPHI_LIVE_TO_AR;

   /******************************************************************************
                  NAME:      P_MOVE_PRISM_DELPHI_TO_HOLD
      PURPOSE:   moving data to holding tank table for the delta from yesterday to today in prism pr delphi po
                 and prism pr delphi po archive tables
      REVISIONS: 1.0
      Date:   1/29/2009
    ******************************************************************************/

   PROCEDURE P_MOVE_PRISM_DELPHI_TO_HOLD (p_contract_num VARCHAR2)
   IS
      -- CHECK IF THERE IS ANY RECORD EXIST IN HOLDING TANK TABLE WITH  ANY DIFFERENCE OF NET QUANTITY ORDERED
      CURSOR C_RECORD_EXIST_IN_HOLD
      IS
         SELECT   pd.*,
                  'CHANGE IN QTY ORDER' RECORD_TYPE_1,
                  'Quantity Ordered has changed from  '
                  || (SELECT   a.quantity_ordered
                        FROM   prism_pr_delphi_po_archive a
                       WHERE       PD.PO_NUMBER = a.PO_NUMBER
                               AND PD.RELEASE_NUM = A.RELEASE_NUM
                               AND PD.LINE_NUM = a.LINE_NUM
                               AND PD.SHIPMENT_NUMBER = a.SHIPMENT_NUMBER
                               AND PD.DISTRIBUTION_NUM = a.DISTRIBUTION_NUM
                               AND PD.QUANTITY_ORDERED <> a.QUANTITY_ORDERED)
                  || ' to '
                  || pd.quantity_ordered
                     RECORD_DETAIL_TEXT
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  AND EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND PD.QUANTITY_ORDERED <>
                                        PDH.QUANTITY_ORDERED)
         -- AND PDH.RECORD_TYPE ='CHANGE IN QTY ORDER')
         UNION
         SELECT   pd.*,
                  'CHANGE IN QTY CANCEL' RECORD_TYPE_1,
                  'Quantity Cancelled has changed from  '
                  || (SELECT   a.quantity_cancelled
                        FROM   prism_pr_delphi_po_archive a
                       WHERE       PD.PO_NUMBER = a.PO_NUMBER
                               AND PD.RELEASE_NUM = A.RELEASE_NUM
                               AND PD.LINE_NUM = a.LINE_NUM
                               AND PD.SHIPMENT_NUMBER = a.SHIPMENT_NUMBER
                               AND PD.DISTRIBUTION_NUM = a.DISTRIBUTION_NUM
                               AND PD.QUANTITY_CANCELLED <>
                                     a.QUANTITY_CANCELLED)
                  || ' to '
                  || pd.quantity_CANCELLED
                     RECORD_DETAIL_TEXT
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  AND EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND PD.QUANTITY_CANCELLED <>
                                        PDH.QUANTITY_CANCELLED)
         -- AND PDH.RECORD_TYPE ='CHANGE IN QTY CANCEL')
         UNION
         SELECT   pd.*,
                  'NEW LINE' RECORD_TYPE_1,
                  'New Line' RECORD_DETAIL_TEXT
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  AND EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND (PD.QUANTITY_ORDERED <>
                                          PDH.QUANTITY_ORDERED
                                       OR PD.QUANTITY_CANCELLED <>
                                            PDH.QUANTITY_CANCELLED)
                                  AND PDH.RECORD_TYPE = 'NEW LINE')
         UNION
         SELECT   pd.*,
                  'CHANGE IN QTY ORD & QTY CANC' RECORD_TYPE_1,
                  'CHANGE IN QTY ORDER AND QTY CANCEL' RECORD_DETAIL_TEXT
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  AND EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND PD.QUANTITY_ORDERED <>
                                        PDH.QUANTITY_ORDERED
                                  AND PD.QUANTITY_CANCELLED <>
                                        PDH.QUANTITY_CANCELLED
                                  AND PDH.RECORD_TYPE =
                                        'CHANGE IN QTY ORD & QTY CANC');

      CURSOR C1_PRISM_PR_DELPHI_PO
      IS
         -- IF THE NEW LINE ITEM IS NOT EXISTS IN ARCHIVE AND HOLD THEN THEN SELECTING FOR THOSE NEW LINE ITEMS
         SELECT   pd.*,
                  'NEW LINE' RECORD_TYPE_1,
                  'New Line' RECORD_DETAIL_TEXT
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  --AND TRUNC(EXTRACT_DATE) = TRUNC(SYSDATE)
                  AND NOT EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_ARCHIVE PDA
                          WHERE       PD.PO_NUMBER = PDA.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDA.RELEASE_NUM
                                  AND PD.LINE_NUM = PDA.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDA.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDA.DISTRIBUTION_NUM)
                  AND NOT EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM -- AND PDH.C_SEND_TO_KITT ='Y'
                                                            )
                  AND NOT EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD_DELETE PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND pd.pr = pdh.pr -- AND ACTION NOT IN ('SEND BACK TO KITT')
                                                    )
         UNION
         -- IF THERE IS ANY NET QUANTITY CHANGED COMPARING WITH ARCHIVE TABLE AND NOT EXISTS IN HOLD TABLE THEN SELECTIGN FOR THOSE RECORDS
         SELECT   pd.*,
                  'CHANGE IN QTY ORDER' RECORD_TYPE_1,
                  'Quantity Ordered has changed from  '
                  || (SELECT   a.quantity_ordered
                        FROM   prism_pr_delphi_po_archive a
                       WHERE       PD.PO_NUMBER = a.PO_NUMBER
                               AND PD.RELEASE_NUM = A.RELEASE_NUM
                               AND PD.LINE_NUM = a.LINE_NUM
                               AND PD.SHIPMENT_NUMBER = a.SHIPMENT_NUMBER
                               AND PD.DISTRIBUTION_NUM = a.DISTRIBUTION_NUM
                               AND PD.QUANTITY_ORDERED <> a.QUANTITY_ORDERED)
                  || ' to '
                  || pd.quantity_ordered
                     RECORD_DETAIL_TEXT
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  --AND TRUNC(EXTRACT_DATE) = TRUNC(SYSDATE)
                  AND EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_ARCHIVE PDA
                          WHERE       PD.PO_NUMBER = PDA.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDA.RELEASE_NUM
                                  AND PD.LINE_NUM = PDA.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDA.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDA.DISTRIBUTION_NUM
                                  AND PD.QUANTITY_ORDERED <>
                                        PDA.QUANTITY_ORDERED)
                  AND NOT EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM -- AND PDH.C_SEND_TO_KITT ='Y'
                                                            )
                  AND NOT EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD_DELETE PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND pd.pr = pdh.pr)
         UNION
         SELECT   pd.*,
                  'CHANGE IN QTY CANCEL' RECORD_TYPE_1,
                  'Quantity Cancelled has changed from  '
                  || (SELECT   a.quantity_cancelled
                        FROM   prism_pr_delphi_po_archive a
                       WHERE       PD.PO_NUMBER = a.PO_NUMBER
                               AND PD.RELEASE_NUM = A.RELEASE_NUM
                               AND PD.LINE_NUM = a.LINE_NUM
                               AND PD.SHIPMENT_NUMBER = a.SHIPMENT_NUMBER
                               AND PD.DISTRIBUTION_NUM = a.DISTRIBUTION_NUM
                               AND PD.QUANTITY_CANCELLED <>
                                     a.QUANTITY_CANCELLED)
                  || ' to '
                  || pd.quantity_cancelled
                     RECORD_DETAIL_TEXT
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  --AND TRUNC(EXTRACT_DATE) = TRUNC(SYSDATE)
                  AND EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_ARCHIVE PDA
                          WHERE       PD.PO_NUMBER = PDA.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDA.RELEASE_NUM
                                  AND PD.LINE_NUM = PDA.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDA.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDA.DISTRIBUTION_NUM
                                  AND PD.QUANTITY_CANCELLED <>
                                        PDA.QUANTITY_CANCELLED)
                  AND NOT EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM -- AND PDH.C_SEND_TO_KITT ='Y'
                                                            )
                  AND NOT EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD_DELETE PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND PD.pr = pdh.pr);

      CURSOR C_EXIST_HOLD_DEL_TBLS
      IS
         SELECT   *
           FROM   PRISM_PR_DELPHI_PO PD
          WHERE   1 = 1 AND PO_NUMBER = p_contract_num
                  AND EXISTS
                        (SELECT   1
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH
                          WHERE       PD.PO_NUMBER = PDH.PO_NUMBER
                                  AND PD.RELEASE_NUM = PDH.RELEASE_NUM
                                  AND PD.LINE_NUM = PDH.LINE_NUM
                                  AND PD.SHIPMENT_NUMBER =
                                        PDH.SHIPMENT_NUMBER
                                  AND PD.DISTRIBUTION_NUM =
                                        PDH.DISTRIBUTION_NUM
                                  AND PDH.RECORD_TYPE = 'NEW LINE')
                  OR EXISTS
                       (SELECT   1
                          FROM   PRISM_PR_DELPHI_PO_HOLD_DELETE PDHD
                         WHERE       PD.PO_NUMBER = PDHD.PO_NUMBER
                                 AND PD.RELEASE_NUM = PDHD.RELEASE_NUM
                                 AND PD.LINE_NUM = PDHD.LINE_NUM
                                 AND PD.SHIPMENT_NUMBER =
                                       PDHD.SHIPMENT_NUMBER
                                 AND PD.DISTRIBUTION_NUM =
                                       PDHD.DISTRIBUTION_NUM
                                 AND PD.PR = PDHD.PR
                                 AND PDHD.RECORD_TYPE = 'NEW LINE');

      -- cursor to remove duplicate records on LSD and combine one
      CURSOR c_duplicates
      IS
           SELECT   PO_NUMBER,
                    RELEASE_NUM,
                    line_num,
                    shipment_number,
                    distribution_num,
                    NVL (do_number, 'NULL')
             FROM   prism_pr_delphi_po_hold h
            WHERE   TRUNC (hold_move_date) = TRUNC (SYSDATE)
                    AND PO_NUMBER = p_contract_num
         GROUP BY   PO_NUMBER,
                    RELEASE_NUM,
                    line_num,
                    shipment_number,
                    distribution_num,
                    NVL (do_number, 'NULL')
           HAVING   COUNT ( * ) > 1
         ORDER BY   LINE_NUM;

      -- cursor to update the flages in prism_pr_delphi_po tabel taking from prism_pr_delphi_po_hold_history
      CURSOR c_update_flags_in_base
      IS
           SELECT   *
             FROM   prism_pr_delphi_po_hold_hist
            WHERE   1 = 1 AND PO_NUMBER = p_contract_num
         ORDER BY   seq_number;
   BEGIN
      FOR RECORD_EXIST_IN_HOLD_ROW IN C_RECORD_EXIST_IN_HOLD
      LOOP
         -- UPDATING THE HOLDING TANK TABLE  FOR NET QUANTITY CHANGED RECORDS
         UPDATE   PRISM_PR_DELPHI_PO_HOLD PDH
            SET   EXTRACT_DATE = SYSDATE,
                  PR = RECORD_EXIST_IN_HOLD_ROW.PR,
                  REQ_TYPE = RECORD_EXIST_IN_HOLD_ROW.REQ_TYPE,
                  PR_DESC = RECORD_EXIST_IN_HOLD_ROW.PR_DESC,
                  PR_LINEITEM_DESC = RECORD_EXIST_IN_HOLD_ROW.PR_LINEITEM_DESC,
                  REQUISITIONER = RECORD_EXIST_IN_HOLD_ROW.REQUISITIONER,
                  CONTRACT_NUM = RECORD_EXIST_IN_HOLD_ROW.CONTRACT_NUM,
                  PR_LI_NUM = RECORD_EXIST_IN_HOLD_ROW.PR_LI_NUM,
                  PR_DIST_AMOUNT = RECORD_EXIST_IN_HOLD_ROW.PR_DIST_AMOUNT,
                  AWARD_PROJECT# = RECORD_EXIST_IN_HOLD_ROW.AWARD_PROJECT#,
                  AWARD_TASK# = RECORD_EXIST_IN_HOLD_ROW.AWARD_TASK#,
                  AWARD_FUNDCODE = RECORD_EXIST_IN_HOLD_ROW.AWARD_FUNDCODE,
                  AWARD_BLI = RECORD_EXIST_IN_HOLD_ROW.AWARD_BLI,
                  AWARD_BUDGETYEAR = RECORD_EXIST_IN_HOLD_ROW.AWARD_BUDGETYEAR,
                  AWARD_OBJECT_CLASS =
                     RECORD_EXIST_IN_HOLD_ROW.AWARD_OBJECT_CLASS,
                  AWARD_BPAC = RECORD_EXIST_IN_HOLD_ROW.AWARD_BPAC,
                  AWARD_EXPENDITUREORG =
                     RECORD_EXIST_IN_HOLD_ROW.AWARD_EXPENDITUREORG,
                  AWARD_EXPENDITURETYPE =
                     RECORD_EXIST_IN_HOLD_ROW.AWARD_EXPENDITURETYPE,
                  AWARD_SGLACCT_CODE =
                     RECORD_EXIST_IN_HOLD_ROW.AWARD_SGLACCT_CODE,
                  AWARD_EXPENDITUREDATE =
                     RECORD_EXIST_IN_HOLD_ROW.AWARD_EXPENDITUREDATE,
                  -- AWARD_ACCOUNT_CODE      = replace(RECORD_EXIST_IN_HOLD_ROW.award_account_code, '.0000000000.0000000000.0000000000.0000000000'),
                  AWARD_ACCOUNT_CODE =
                     RECORD_EXIST_IN_HOLD_ROW.award_account_code,
                  AWARD_LI_NUM = RECORD_EXIST_IN_HOLD_ROW.AWARD_LI_NUM,
                  shipment# = RECORD_EXIST_IN_HOLD_ROW.shipment#,
                  DIST# = RECORD_EXIST_IN_HOLD_ROW.DIST#,
                  NAME_POC = RECORD_EXIST_IN_HOLD_ROW.NAME_POC,
                  --   ORIGINATING_OFFICE_DATA = RECORD_EXIST_IN_HOLD_ROW.ORIGINATING_OFFICE || '/' || RECORD_EXIST_IN_HOLD_ROW.ORIGINATION_OFFICE_NAME,
                  --  ORIGINATION_OFFICE_NAME      = RECORD_EXIST_IN_HOLD_ROW.ORIGINATION_OFFICE_NAME,
                  --  REQUISITIONER_INFO           = RECORD_EXIST_IN_HOLD_ROW.REQUISITIONER_INF
                  REQUISITION_DATE = RECORD_EXIST_IN_HOLD_ROW.REQUISITION_DATE,
                  CONSIGNEE_AND_DESTINATION =
                     RECORD_EXIST_IN_HOLD_ROW.CONSIGNEE_AND_DESTINATION,
                  DATES_REQUIRED = RECORD_EXIST_IN_HOLD_ROW.DATES_REQUIRED,
                  CONTRACT_AUTHORITY_FURNISHED =
                     RECORD_EXIST_IN_HOLD_ROW.CONTRACT_AUTHORITY_FURNISHED,
                  TYPE_OF_FUNDS = RECORD_EXIST_IN_HOLD_ROW.TYPE_OF_FUNDS,
                  EXPENDITURE_EXPIRATION_DATE =
                     RECORD_EXIST_IN_HOLD_ROW.EXPENDITURE_EXPIRATION_DATE,
                  FUND_DESCRIPTION = RECORD_EXIST_IN_HOLD_ROW.FUND_DESCRIPTION,
                  CONTRACT_MOD# = RECORD_EXIST_IN_HOLD_ROW.CONTRACT_MOD#,
                  --- delphi data
                  D_EXTRACT_DATE = RECORD_EXIST_IN_HOLD_ROW.D_EXTRACT_DATE,
                  PO_NUMBER = RECORD_EXIST_IN_HOLD_ROW.PO_NUMBER,
                  VENDOR_NAME = RECORD_EXIST_IN_HOLD_ROW.VENDOR_NAME,
                  VENDOR_SITE_CODE = RECORD_EXIST_IN_HOLD_ROW.VENDOR_SITE_CODE,
                  RELEASE_NUM = RECORD_EXIST_IN_HOLD_ROW.RELEASE_NUM,
                  LINE_ITEM = RECORD_EXIST_IN_HOLD_ROW.LINE_ITEM,
                  MATCHING_TYPE = RECORD_EXIST_IN_HOLD_ROW.MATCHING_TYPE,
                  QUANTITY_ORDERED = RECORD_EXIST_IN_HOLD_ROW.QUANTITY_ORDERED,
                  QUANTITY_BILLED = RECORD_EXIST_IN_HOLD_ROW.QUANTITY_BILLED,
                  QUANTITY_RECEIVED =
                     RECORD_EXIST_IN_HOLD_ROW.QUANTITY_RECEIVED,
                  QUANTITY_CANCELLED =
                     RECORD_EXIST_IN_HOLD_ROW.QUANTITY_CANCELLED,
                  OBLIGATED_BALANCE =
                     RECORD_EXIST_IN_HOLD_ROW.OBLIGATED_BALANCE,
                  PROJECT_NUMBER = RECORD_EXIST_IN_HOLD_ROW.PROJECT_NUMBER,
                  TASK_NUMBER = RECORD_EXIST_IN_HOLD_ROW.TASK_NUMBER,
                  CHARGE_ACCOUNT = RECORD_EXIST_IN_HOLD_ROW.CHARGE_ACCOUNT,
                  MULTIPLIER = RECORD_EXIST_IN_HOLD_ROW.MULTIPLIER,
                  FUND = RECORD_EXIST_IN_HOLD_ROW.FUND,
                  BUDYEAR = RECORD_EXIST_IN_HOLD_ROW.BUDYEAR,
                  BPAC = RECORD_EXIST_IN_HOLD_ROW.BPAC,
                  ORGCODE = RECORD_EXIST_IN_HOLD_ROW.ORGCODE,
                  OBJECT_CLASS = RECORD_EXIST_IN_HOLD_ROW.OBJECT_CLASS,
                  ACCOUNT = RECORD_EXIST_IN_HOLD_ROW.ACCOUNT,
                  LINE_NUM = RECORD_EXIST_IN_HOLD_ROW.LINE_NUM,
                  SHIPMENT_NUMBER = RECORD_EXIST_IN_HOLD_ROW.SHIPMENT_NUMBER,
                  DISTRIBUTION_NUM = RECORD_EXIST_IN_HOLD_ROW.DISTRIBUTION_NUM,
                  RECORD_TYPE = RECORD_EXIST_IN_HOLD_ROW.RECORD_TYPE_1,
                  NET_QTY_ORDERED = RECORD_EXIST_IN_HOLD_ROW.NET_QTY_ORDERED,
                  RECORD_DETAIL_TEXT =
                     RECORD_EXIST_IN_HOLD_ROW.RECORD_DETAIL_TEXT,
                  PMO_NOTIFIED_FLAG = 'N'
          WHERE       PDH.PO_NUMBER = RECORD_EXIST_IN_HOLD_ROW.PO_NUMBER
                  AND PDH.RELEASE_NUM = RECORD_EXIST_IN_HOLD_ROW.RELEASE_NUM
                  AND PDH.LINE_NUM = RECORD_EXIST_IN_HOLD_ROW.LINE_NUM
                  AND PDH.SHIPMENT_NUMBER =
                        RECORD_EXIST_IN_HOLD_ROW.SHIPMENT_NUMBER
                  AND PDH.DISTRIBUTION_NUM =
                        RECORD_EXIST_IN_HOLD_ROW.DISTRIBUTION_NUM;          --
      -- P_JOB_EVENT_DETAIL('DELPHI PO','Success','Successfully deleted the record in prism_pr_delphi_po table if the record already exist in holding table');

      END LOOP;


      FOR PRISM_PR_DEL_PO_ROW IN C1_PRISM_PR_DELPHI_PO
      LOOP
         -- inserting data from prism_pr_delphi_po to prism_pr_delphi_po_hold table for the delta
         INSERT INTO prism_pr_delphi_po_hold
           VALUES   (hold_seq_number.NEXTVAL,
                     SYSDATE,                                -- HOLD_MOVE_DATE
                     PRISM_PR_DEL_PO_ROW.EXTRACT_DATE,
                     PRISM_PR_DEL_PO_ROW.PR,
                     PRISM_PR_DEL_PO_ROW.REQ_TYPE,
                     PRISM_PR_DEL_PO_ROW.PR_DESC,
                     PRISM_PR_DEL_PO_ROW.PR_LINEITEM_DESC,
                     PRISM_PR_DEL_PO_ROW.REQUISITIONER,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_NUM,
                     PRISM_PR_DEL_PO_ROW.PR_LI_NUM,
                     PRISM_PR_DEL_PO_ROW.PR_DIST_AMOUNT,
                     PRISM_PR_DEL_PO_ROW.AWARD_PROJECT#,
                     PRISM_PR_DEL_PO_ROW.AWARD_TASK#,
                     PRISM_PR_DEL_PO_ROW.AWARD_FUNDCODE,
                     PRISM_PR_DEL_PO_ROW.AWARD_BLI,
                     PRISM_PR_DEL_PO_ROW.AWARD_BUDGETYEAR,
                     PRISM_PR_DEL_PO_ROW.AWARD_OBJECT_CLASS,
                     PRISM_PR_DEL_PO_ROW.AWARD_BPAC,
                     PRISM_PR_DEL_PO_ROW.AWARD_EXPENDITUREORG,
                     PRISM_PR_DEL_PO_ROW.AWARD_EXPENDITURETYPE,
                     PRISM_PR_DEL_PO_ROW.AWARD_SGLACCT_CODE,
                     PRISM_PR_DEL_PO_ROW.AWARD_EXPENDITUREDATE,
                     PRISM_PR_DEL_PO_ROW.AWARD_ACCOUNT_CODE,
                     PRISM_PR_DEL_PO_ROW.AWARD_LI_NUM,
                     PRISM_PR_DEL_PO_ROW.SHIPMENT#,
                     PRISM_PR_DEL_PO_ROW.DIST#,
                     PRISM_PR_DEL_PO_ROW.NAME_POC,
                     PRISM_PR_DEL_PO_ROW.ORIGINATING_OFFICE_DATA,
                     PRISM_PR_DEL_PO_ROW.REQUISITION_DATE,
                     PRISM_PR_DEL_PO_ROW.CONSIGNEE_AND_DESTINATION,
                     PRISM_PR_DEL_PO_ROW.DATES_REQUIRED,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_AUTHORITY_FURNISHED,
                     PRISM_PR_DEL_PO_ROW.TYPE_OF_FUNDS,
                     PRISM_PR_DEL_PO_ROW.EXPENDITURE_EXPIRATION_DATE,
                     PRISM_PR_DEL_PO_ROW.FUND_DESCRIPTION,
                     PRISM_PR_DEL_PO_ROW.D_EXTRACT_DATE,
                     PRISM_PR_DEL_PO_ROW.PO_NUMBER,
                     PRISM_PR_DEL_PO_ROW.VENDOR_NAME,
                     PRISM_PR_DEL_PO_ROW.VENDOR_SITE_CODE,
                     PRISM_PR_DEL_PO_ROW.RELEASE_NUM,
                     PRISM_PR_DEL_PO_ROW.LINE_ITEM,
                     PRISM_PR_DEL_PO_ROW.MATCHING_TYPE,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_ORDERED,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_BILLED,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_RECEIVED,
                     PRISM_PR_DEL_PO_ROW.QUANTITY_CANCELLED,
                     PRISM_PR_DEL_PO_ROW.OBLIGATED_BALANCE,
                     PRISM_PR_DEL_PO_ROW.PROJECT_NUMBER,
                     PRISM_PR_DEL_PO_ROW.TASK_NUMBER,
                     PRISM_PR_DEL_PO_ROW.CHARGE_ACCOUNT,
                     PRISM_PR_DEL_PO_ROW.MULTIPLIER,
                     PRISM_PR_DEL_PO_ROW.FUND,
                     PRISM_PR_DEL_PO_ROW.BUDYEAR,
                     PRISM_PR_DEL_PO_ROW.BPAC,
                     PRISM_PR_DEL_PO_ROW.ORGCODE,
                     PRISM_PR_DEL_PO_ROW.OBJECT_CLASS,
                     PRISM_PR_DEL_PO_ROW.ACCOUNT,
                     PRISM_PR_DEL_PO_ROW.LINE_NUM,
                     PRISM_PR_DEL_PO_ROW.SHIPMENT_NUMBER,
                     PRISM_PR_DEL_PO_ROW.DISTRIBUTION_NUM,
                     PRISM_PR_DEL_PO_ROW.NET_QTY_ORDERED,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_MOD#,
                     PRISM_PR_DEL_PO_ROW.RECORD_TYPE_1,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     PRISM_PR_DEL_PO_ROW.CONTRACT_MOD_SUBTOTAL,
                     PRISM_PR_DEL_PO_ROW.RECORD_DETAIL_TEXT,
                     PRISM_PR_DEL_PO_ROW.DO_NUMBER,
                     PRISM_PR_DEL_PO_ROW.AWARD_TYPE);

         -- after moved the delta in holding tank table then removing that record in prism_pr_delphi_po base table
         IF PRISM_PR_DEL_PO_ROW.RECORD_TYPE_1 = 'NEW LINE'
         THEN
            --null;

            --         DELETE FROM PRISM_PR
            --         WHERE CONTRACT_NUM = PRISM_PR_DEL_PO_ROW.CONTRACT_NUM
            --           AND AWARD_LI_NUM = PRISM_PR_DEL_PO_ROW.AWARD_LI_NUM
            --           AND SHIPMENT# = PRISM_PR_DEL_PO_ROW.SHIPMENT#
            --           AND DIST# = PRISM_PR_DEL_PO_ROW.DISTRIBUTION_NUM;
            --
            --
            --         DELETE FROM DELPHI_PO
            --         WHERE PO_NUMBER = PRISM_PR_DEL_PO_ROW.PO_NUMBER
            --           AND LINE_NUM = PRISM_PR_DEL_PO_ROW.LINE_NUM
            --           AND SHIPMENT_NUMBER = PRISM_PR_DEL_PO_ROW.SHIPMENT_NUMBER
            --           AND DISTRIBUTION_NUM = PRISM_PR_DEL_PO_ROW.DISTRIBUTION_NUM;


            DELETE FROM   PRISM_PR_DELPHI_PO
                  WHERE       PO_NUMBER = PRISM_PR_DEL_PO_ROW.PO_NUMBER
                          AND RELEASE_NUM = PRISM_PR_DEL_PO_ROW.RELEASE_NUM
                          AND LINE_NUM = PRISM_PR_DEL_PO_ROW.LINE_NUM
                          AND SHIPMENT_NUMBER =
                                PRISM_PR_DEL_PO_ROW.SHIPMENT_NUMBER
                          AND DISTRIBUTION_NUM =
                                PRISM_PR_DEL_PO_ROW.DISTRIBUTION_NUM;
         END IF;
      END LOOP;



      FOR EXIST_HOLD_DEL_TBLS_ROW IN C_EXIST_HOLD_DEL_TBLS
      LOOP
         DELETE FROM   PRISM_PR_DELPHI_PO PD
               WHERE   1 = 1
                       AND PD.PO_NUMBER = EXIST_HOLD_DEL_TBLS_ROW.PO_NUMBER
                       AND PD.RELEASE_NUM =
                             EXIST_HOLD_DEL_TBLS_ROW.RELEASE_NUM
                       AND PD.LINE_NUM = EXIST_HOLD_DEL_TBLS_ROW.LINE_NUM
                       AND PD.SHIPMENT_NUMBER =
                             EXIST_HOLD_DEL_TBLS_ROW.SHIPMENT_NUMBER
                       AND PD.DISTRIBUTION_NUM =
                             EXIST_HOLD_DEL_TBLS_ROW.DISTRIBUTION_NUM;
      END LOOP;


      FOR duplicates_ROW IN C_duplicates
      LOOP
         UPDATE   PRISM_PR_DELPHI_PO_HOLD PDH
            SET   RECORD_TYPE = 'CHANGE IN QTY ORD & QTY CANC',
                  RECORD_DETAIL_TEXT =
                     PDH.RECORD_DETAIL_TEXT || ' AND also '
                     || (SELECT   PDH2.RECORD_DETAIL_TEXT
                           FROM   PRISM_PR_DELPHI_PO_HOLD PDH2
                          WHERE   PDH2.PO_NUMBER = duplicates_row.PO_NUMBER
                                  AND PDH2.LINE_NUM = duplicates_row.LINE_NUM
                                  AND PDH2.SHIPMENT_NUMBER =
                                        duplicates_row.SHIPMENT_NUMBER
                                  AND PDH2.DISTRIBUTION_NUM =
                                        duplicates_row.DISTRIBUTION_NUM
                                  AND PDH2.RECORD_TYPE =
                                        'CHANGE IN QTY CANCEL'
                                  AND TRUNC (PDH2.hold_move_date) =
                                        TRUNC (SYSDATE))
          WHERE       PDH.PO_NUMBER = duplicates_row.PO_NUMBER
                  AND PDH.RELEASE_NUM = duplicates_row.RELEASE_NUM
                  AND PDH.LINE_NUM = duplicates_row.LINE_NUM
                  AND PDH.SHIPMENT_NUMBER = duplicates_row.SHIPMENT_NUMBER
                  AND PDH.DISTRIBUTION_NUM = duplicates_row.DISTRIBUTION_NUM
                  AND PDH.RECORD_TYPE = 'CHANGE IN QTY ORDER'
                  AND TRUNC (PDH.hold_move_date) = TRUNC (SYSDATE);

         DELETE FROM   PRISM_PR_DELPHI_PO_HOLD PDH
               WHERE       PDH.PO_NUMBER = duplicates_row.PO_NUMBER
                       AND PDH.RELEASE_NUM = duplicates_row.RELEASE_NUM
                       AND PDH.LINE_NUM = duplicates_row.LINE_NUM
                       AND PDH.SHIPMENT_NUMBER =
                             duplicates_row.SHIPMENT_NUMBER
                       AND PDH.DISTRIBUTION_NUM =
                             duplicates_row.DISTRIBUTION_NUM
                       AND PDH.RECORD_TYPE = 'CHANGE IN QTY CANCEL'
                       AND TRUNC (PDH.hold_move_date) = TRUNC (SYSDATE);
      END LOOP;


      FOR update_flags_in_base IN c_update_flags_in_base
      LOOP
         UPDATE   PRISM_PR_DELPHI_PO PD
            SET   RECORD_TYPE = update_flags_in_base.record_type,
                  C_HOLD = update_flags_in_base.c_hold,
                  C_DELETE = update_flags_in_base.c_delete,
                  C_SEND_TO_KITT = update_flags_in_base.c_send_to_kitt,
                  C_CORE = update_flags_in_base.c_core,
                  C_DEOBLIGATE = update_flags_in_base.c_deobligate,
                  C_EXEMPT = update_flags_in_base.c_exempt,
                  ACTION_TAKEN_DATE = update_flags_in_base.action_taken_date,
                  PMO_NOTIFIED_FLAG = update_flags_in_base.pmo_notified_flag
          WHERE       PD.PO_NUMBER = update_flags_in_base.PO_NUMBER
                  AND PD.RELEASE_NUM = update_flags_in_base.release_num
                  AND PD.LINE_NUM = update_flags_in_base.LINE_NUM
                  AND PD.SHIPMENT_NUMBER =
                        update_flags_in_base.SHIPMENT_NUMBER
                  AND PD.DISTRIBUTION_NUM =
                        update_flags_in_base.DISTRIBUTION_NUM
                  AND pd.pr = update_flags_in_base.pr
                  AND pd.pr_li_num = update_flags_in_base.pr_li_num
                  AND pd.req_type = update_flags_in_base.req_type;
      END LOOP;

      -- calling job detail procedure to update the job detail information
      P_JOB_EVENT_DETAIL (
         'PRISM PR',
         'Success',
         'Successfully Loaded prism_pr_delphi_po data into holding tank table for the contract '
         || p_contract_num
      );
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR DELPHI PO',
            'Fail',
            'Failed to load date from  PRISM PR DELPHI PO TO HOLD Table for the contract '
            || p_contract_num
            || '  '
            || 'Oracle Error msg'
            || SQLERRM
         );
         raise_application_error (
            -20022,
            'An error was encountered while moving data from PRISM PR DELPHI PO to hold Table- '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_MOVE_PRISM_DELPHI_TO_HOLD;

   /******************************************************************************
                  NAME:       PRISM_PR_DELPHI_PO_MAIN
      PURPOSE:    Delphi main prcedure to call all other sub procedures
      REVISIONS: 1.0
      Date:   1/29/2009
    ******************************************************************************/
   PROCEDURE P_PRISM_PR_DELPHI_PO_MAIN
   IS
      CURSOR c_contract_info
      IS
           SELECT   *
             FROM   contract_info
            WHERE   1 = 1
         --and contract_num IN  ('DTFAWA-11-C-00003') --,'DTFAWA-10-D-00007','DTFAWA-09-C-00030','DTFAWA-08-C-00009')
         ORDER BY   contract_num;

      V_DELTA_IDENTIFY   NUMBER;
   BEGIN
      P_MOVE_PRISM_DELPHI_LIVE_TO_AR;

      FOR contract_info_row IN c_contract_info
      LOOP
         V_DELTA_IDENTIFY := F_IDENTIFY_DELTA (contract_info_row.contract_num);

         IF V_DELTA_IDENTIFY = 1
         THEN
            BEGIN
               P_MOVE_PRISM_PR_STAGE (contract_info_row.contract_num);
               P_PRISM_UPDATE_STAGE_TBL;
               P_MOVE_PRISM_LIVE_TO_ARCHIVE (contract_info_row.contract_num); -- archiving

               p_move_delphi_live_to_Archive (contract_info_row.contract_num); -- archiving

               P_move_delphi_stage_to_live (contract_info_row.contract_num);

               P_MOVE_PRISM_STAGE_TO_LIVE (contract_info_row.contract_num);

               P_AVOID_DUP_PRS_EXCEPTION (contract_info_row.contract_num);

               P_MOVE_PRISM_PR_DELPHI_PO (contract_info_row.contract_num);

               P_MOVE_PRISM_DELPHI_TO_HOLD (contract_info_row.contract_num);

               P_UPDATE_PRISM_LI_TOTAL_AMT (contract_info_row.contract_num); --P_update_reqformod_prs;

               COMMIT;
            --p_changes_email_notification1(contract_info_row.contract_num);
            --p_changes_email_notification(contract_info_row.contract_num);

            EXCEPTION
               WHEN OTHERS
               THEN
                  ROLLBACK;
            END;
         ELSE
            --  if the delta has not been identified then just update the prism and delphi base tables extract data as today's date
            UPDATE   prism_pr
               SET   extract_date = SYSDATE
             WHERE   contract_num = contract_info_row.contract_num;

            UPDATE   delphi_po
               SET   extract_date = SYSDATE
             WHERE   po_number = contract_info_row.contract_num;

            UPDATE   prism_pr_delphi_po
               SET   extract_date = SYSDATE
             WHERE   po_number = contract_info_row.contract_num;

            P_JOB_EVENT_DETAIL (
               'DELPHI PO',
               'Success',
               'Delta has not identified any changes and there are no new or changes to existing records in delphi when compared between yesterday and today. '
               || contract_info_row.contract_num
            );
         END IF;


         COMMIT;
      END LOOP;
   END P_PRISM_PR_DELPHI_PO_MAIN;

   /******************************************************************************
                              NAME:       P_JOB_EVENT_DETAIL
      PURPOSE:    Capture event log of the process
      REVISIONS: 1.0
      Date:   2/29/2009
    ******************************************************************************/
   PROCEDURE P_JOB_EVENT_DETAIL (p_event_module_nm     varchar2,
                                 p_event_short_desc    varchar2,
                                 p_event_long_desc     varchar2)
   IS
      -- p_job_desc varchar2(300);
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO PRISM_DELPHI_JOB_EVENT_DETAIL
        VALUES   (TRUNC (SYSDATE),
                  SYSDATE,
                  p_event_module_nm,
                  p_event_short_desc,
                  p_event_long_desc);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         raise_application_error (
            -20010,
            'An error was encountered while populating data into PRISM_DELPHI_JOB_EVENT_DETAIL table - '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_JOB_EVENT_DETAIL;

   /******************************************************************************
                NAME:       P_JOB_EVENT_DETAIL
    PURPOSE:    Capture event log of the process
    REVISIONS: 1.0
    Date:   2/29/2009
  ******************************************************************************/
   PROCEDURE P_BUSINESS_LOGIC_AUDIT_LOGS (p_event_short_desc    varchar2,
                                          p_event_long_desc     varchar2)
   IS
   -- p_job_desc varchar2(300);
   -- PRAGMA AUTONOMOUS_TRANSACTION;

   BEGIN
      INSERT INTO PRISM_DELPHI_JOB_EVENT_DETAIL
        VALUES   (TRUNC (SYSDATE),
                  SYSDATE,
                  'KFDB_Business_Rules',
                  p_event_short_desc,
                  p_event_long_desc);

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         raise_application_error (
            -20010,
            'An error was encountered while populating data into PRISM_DELPHI_JOB_EVENT_DETAIL table - '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_BUSINESS_LOGIC_AUDIT_LOGS;

   /******************************************************************************
           NAME:       changes_email_notification
     PURPOSE:
     REVISIONS: 1.0
     Date:   05/12/2009
   ******************************************************************************/
   PROCEDURE p_changes_email_notification1 (p_contract_num varchar2)
   IS
      --v_msg varchar2(32700):='RECORD TYPE         LINE#       SHIPMENT#       DIST#      QTY_ORDERED    QTY_CANCELLED    CONTRACT_MOD#    CONTRACT_MOD_SUBTOTAL';
      v_msg varchar2 (32700)
            := 'RECORD TYPE        LINE#            SHIPMENT#         DIST#       QTY_ORDERED     QTY_CANCELLED    CONTRACT_MOD#     CONTRACT_MOD_SUBTOTAL' ;
      v_msg1         varchar2 (32700);
      v_msg2         varchar2 (32700);
      v_receiver     varchar2 (300);
      v_hold_cnt     number;
      V_EMAIL_LIST   VARCHAR2 (4000);

      CURSOR C_CONTRACT_INFO
      IS
           SELECT   CONTRACT_NUM
             FROM   CONTRACT_INFO
            WHERE   contract_num = p_contract_num
         ORDER BY   CONTRACT_NUM;

      CURSOR QTY_CANC_C (
         P_CONTRACT_NUM                 VARCHAR2
      )
      IS
           SELECT   DECODE (RECORD_TYPE,
                            'CHANGE IN QTY ORDER', 'QTY ORD',
                            'CHANGE IN QTY CANCEL', 'QTY CANC',
                            RECORD_TYPE)
                       RECORD_TYPE,
                    RPAD (LINE_NUM, 5) line_num,
                    RPAD (SHIPMENT_NUMBER, 8) SHIPMENT_NUMBER,
                    RPAD (DISTRIBUTION_NUM, 4) DISTRIBUTION_NUM,
                    LPAD (ROUND (QUANTITY_ORDERED), 9) QUANTITY_ORDERED,
                    LPAD (ROUND (QUANTITY_CANCELLED), 9) QUANTITY_CANCELLED,
                    LPAD (CONTRACT_MOD#, 9) contract_mod#,
                    ROUND (CONTRACT_MOD_SUBTOTAL) CONTRACT_MOD_SUBTOTAL
             FROM   PRISM_PR_DELPHI_PO_HOLD
            WHERE       NVL (PMO_NOTIFIED_FLAG, 'N') <> 'Y'
                    AND RECORD_TYPE <> 'CHANGE IN QTY CANCEL'
                    AND CONTRACT_NUM = P_CONTRACT_NUM
         ORDER BY   line_num, distribution_num;

      CURSOR C_EMAIL_LIST (
         p_contract_num                 varchar2
      )
      IS
         SELECT   'Surekha.CTR.Kandula@faa.gov' pmo_email FROM DUAL
         UNION
         SELECT   pmo_email
           FROM   CONTRACT_PMO_EMAIL_LOOKUP
          WHERE   contract_num = p_contract_num
                  AND pmo_email NOT IN
                           ('Preston.Hertzler@faa.gov',
                            'Ajit.CTR.Behera@faa.gov',
                            'sjawn.h.wade@faa.gov',
                            'fei.ctr.xue@faa.gov',
                            'nicholson.ctr.prosper@faa.gov',
                            'kha.ctr.pham@faa.gov',
                            'ron.j.gatling@faa.gov');

      v_count        number := 0;
   BEGIN
      FOR CONTRACT_INFO_ROW IN C_CONTRACT_INFO
      LOOP
         FOR QTY_CANC_REC IN QTY_CANC_C (CONTRACT_INFO_ROW.CONTRACT_NUM)
         LOOP
            v_msg :=
                  v_msg
               || CHR (10)
               || QTY_CANC_REC.RECORD_TYPE
               || CHR (9)
               || QTY_CANC_REC.LINE_NUM
               || CHR (9)
               || QTY_CANC_REC.SHIPMENT_NUMBER
               || CHR (9)
               || QTY_CANC_REC.DISTRIBUTION_NUM
               || CHR (9)
               || QTY_CANC_REC.QUANTITY_ORDERED
               || CHR (9)
               || QTY_CANC_REC.QUANTITY_CANCELLED
               || CHR (9)
               || QTY_CANC_REC.Contract_mod#
               || CHR (9)
               || ' '
               || CHR (9)
               || QTY_CANC_REC.CONTRACT_MOD_SUBTOTAL;


            v_count := v_count + 1;
         END LOOP;

         SELECT   COUNT ( * )
           INTO   v_hold_cnt
           FROM   prism_pr_delphi_po_hold
          WHERE       NVL (PMO_NOTIFIED_FLAG, 'N') <> 'Y'
                  AND RECORD_TYPE <> 'CHANGE IN QTY CANCEL'
                  AND CONTRACT_NUM = CONTRACT_INFO_ROW.CONTRACT_NUM;

         -- if the record exists in holding tank table and pmp notified flag is not equal to "Y" then notify those records to PMOs
         IF v_hold_cnt > 0
         THEN
            FOR EMAIL_LIST_ROW
            IN C_EMAIL_LIST (CONTRACT_INFO_ROW.CONTRACT_NUM)
            LOOP
               KITT_SEND_EMAIL (
                  'Surekha.CTR.Kandula@FAA.gov',
                  email_list_row.pmo_email, --V_EMAIL_LIST, --'Surekha.CTR.Kandula@FAA.gov',
                  'PMO attention is needed due to change in Delphi records for Contract#  '
                  || CONTRACT_INFO_ROW.CONTRACT_NUM,
                  v_msg
               );
            END LOOP;
         END IF;
      END LOOP;

      --commit;


      UPDATE   prism_pr_delphi_po_hold
         SET   PMO_NOTIFIED_FLAG = 'Y'
       WHERE       1 = 1
               AND RECORD_TYPE <> 'CHANGE IN QTY CANCEL'
               AND po_number = p_contract_num
               AND EXISTS
                     (SELECT   1
                        FROM   PRISM_PR_DELPHI_PO_HOLD
                       WHERE       NVL (PMO_NOTIFIED_FLAG, 'N') <> 'Y'
                               AND RECORD_TYPE <> 'CHANGE IN QTY CANCEL'
                               AND po_number = p_contract_num);
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR DELPHI PO',
            'Fail',
               'Failed to send an email notification'
            || '  '
            || 'Oracle Error msg'
            || SQLERRM
         );
         raise_application_error (
            -20022,
            'An error was encountered while sending an email notification- '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END p_changes_email_notification1;

   /******************************************************************************
                 NAME:       p_error_email_notification
     PURPOSE:
     REVISIONS: 1.0
     Date:   10/02/2009
   ******************************************************************************/
   PROCEDURE p_error_email_notification
   IS
      v_msg varchar2 (32700)
            := 'EVENT_RUN_DATE,       EVENT_MODULE_NM,       EVENT_SHORT_DESC,       EVENT_DETAIL_DESC' ;
      v_receiver     varchar2 (300);
      v_error_cnt    number;
      V_EMAIL_LIST   VARCHAR2 (4000);

      CURSOR ERROR_MSG_C
      IS
         SELECT   EVENT_RUN_DATE,
                  EVENT_MODULE_NM,
                  EVENT_SHORT_DESC,
                  EVENT_DETAIL_DESC
           FROM   PRISM_DELPHI_JOB_EVENT_DETAIL
          WHERE   EVENT_SHORT_DESC = 'Fail'
                  AND TRUNC (EVENT_RUN_DATE) = TRUNC (SYSDATE);

      CURSOR C_EMAIL_LIST
      IS
         SELECT   'Surekha.CTR.Kandula@faa.gov' pmo_email FROM DUAL;

      --union
      --select 'Chandra.CTR.Edara@faa.gov' pmo_email from dual ;


      v_count        number := 0;
   BEGIN
      FOR ERROR_MSG_REC IN ERROR_MSG_C
      LOOP
         v_msg :=
               v_msg
            || CHR (10)
            || ERROR_MSG_REC.EVENT_RUN_DATE
            || CHR (9)
            || ERROR_MSG_REC.EVENT_MODULE_NM
            || CHR (9)
            || ERROR_MSG_REC.EVENT_SHORT_DESC
            || CHR (9)
            || ERROR_MSG_REC.EVENT_DETAIL_DESC;

         v_count := v_count + 1;
      END LOOP;

      SELECT   COUNT ( * )
        INTO   v_error_cnt
        FROM   PRISM_DELPHI_JOB_EVENT_DETAIL
       WHERE   EVENT_SHORT_DESC = 'Fail'
               AND TRUNC (EVENT_RUN_DATE) = TRUNC (SYSDATE);

      -- if the record exists in holding tank table and pmp notified flag is not equal to "Y" then notify those records to PMOs
      IF v_error_cnt > 0
      THEN
         FOR EMAIL_LIST_ROW IN C_EMAIL_LIST
         LOOP
            KITT_SEND_EMAIL (
               'Surekha.CTR.Kandula@FAA.gov',
               email_list_row.pmo_email, --V_EMAIL_LIST, --'Surekha.CTR.Kandula@FAA.gov',
               'Failed to refresh the KITT tables for contract DTFAWA-08-C-00009',
               v_msg
            );
         END LOOP;
      END IF;
   --P_JOB_EVENT_DETAIL('PRISM PR DELPHI PO','Success','Successfully send an email notification if they are any changes in financials data');


   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR DELPHI PO',
            'Fail',
            'Failed to send an email notification for job even detail error related data'
            || '  '
            || 'Oracle Error msg'
            || SQLERRM
         );
         raise_application_error (
            -20032,
            'An error was encountered while sending an email notification for error records - '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END p_error_email_notification;

   /******************************************************************************
            NAME:       changes_email_notification
      PURPOSE:
      REVISIONS: 1.0
      Date:   05/12/2009
    ******************************************************************************/
   PROCEDURE p_changes_email_notification (p_contract_num varchar2)
   IS
      --v_msg varchar2(32700):='RECORD TYPE         LINE#       SHIPMENT#       DIST#      QTY_ORDERED    QTY_CANCELLED    CONTRACT_MOD#    CONTRACT_MOD_SUBTOTAL';
      v_msg varchar2 (32700)
            := 'RECORD TYPE        LINE#            SHIPMENT#         DIST#       QTY_ORDERED     QTY_CANCELLED    CONTRACT_MOD#     CONTRACT_MOD_SUBTOTAL' ;
      v_msg1         varchar2 (32700);
      v_msg2         varchar2 (32700);
      v_receiver     varchar2 (300);
      v_hold_cnt     number;
      V_EMAIL_LIST   VARCHAR2 (4000);

      CURSOR C_CONTRACT_INFO
      IS
           SELECT   CONTRACT_NUM
             FROM   CONTRACT_INFO
            WHERE   contract_num = p_contract_num
         ORDER BY   CONTRACT_NUM;

      CURSOR QTY_CANC_C (
         P_CONTRACT_NUM                 VARCHAR2
      )
      IS
           SELECT   DECODE (RECORD_TYPE,
                            'CHANGE IN QTY ORDER', 'QTY ORD',
                            'CHANGE IN QTY CANCEL', 'QTY CANC',
                            RECORD_TYPE)
                       RECORD_TYPE,
                    RPAD (LINE_NUM, 5) line_num,
                    RPAD (SHIPMENT_NUMBER, 8) SHIPMENT_NUMBER,
                    RPAD (DISTRIBUTION_NUM, 4) DISTRIBUTION_NUM,
                    LPAD (ROUND (QUANTITY_ORDERED), 9) QUANTITY_ORDERED,
                    LPAD (ROUND (QUANTITY_CANCELLED), 9) QUANTITY_CANCELLED,
                    LPAD (CONTRACT_MOD#, 9) contract_mod#,
                    ROUND (CONTRACT_MOD_SUBTOTAL) CONTRACT_MOD_SUBTOTAL
             FROM   PRISM_PR_DELPHI_PO_HOLD
            WHERE       NVL (PMO_NOTIFIED_FLAG, 'N') <> 'Y'
                    AND RECORD_TYPE = 'CHANGE IN QTY CANCEL'
                    AND CONTRACT_NUM = P_CONTRACT_NUM
         ORDER BY   line_num, distribution_num;

      CURSOR C_EMAIL_LIST (
         p_contract_num                 varchar2
      )
      IS
         SELECT   'Surekha.CTR.Kandula@faa.gov' pmo_email FROM DUAL
         UNION
         SELECT   pmo_email
           FROM   CONTRACT_PMO_EMAIL_LOOKUP
          WHERE   contract_num = p_contract_num
                  AND pmo_email NOT IN
                           ('Preston.Hertzler@faa.gov',
                            'Ajit.CTR.Behera@faa.gov',
                            'sjawn.h.wade@faa.gov',
                            'fei.ctr.xue@faa.gov',
                            'nicholson.ctr.prosper@faa.gov',
                            'kha.ctr.pham@faa.gov',
                            'ron.j.gatling@faa.gov');

      v_count        number := 0;
   BEGIN
      FOR CONTRACT_INFO_ROW IN C_CONTRACT_INFO
      LOOP
         FOR QTY_CANC_REC IN QTY_CANC_C (CONTRACT_INFO_ROW.CONTRACT_NUM)
         LOOP
            v_msg :=
                  v_msg
               || CHR (10)
               || QTY_CANC_REC.RECORD_TYPE
               || CHR (9)
               || QTY_CANC_REC.LINE_NUM
               || CHR (9)
               || QTY_CANC_REC.SHIPMENT_NUMBER
               || CHR (9)
               || QTY_CANC_REC.DISTRIBUTION_NUM
               || CHR (9)
               || QTY_CANC_REC.QUANTITY_ORDERED
               || CHR (9)
               || QTY_CANC_REC.QUANTITY_CANCELLED
               || CHR (9)
               || QTY_CANC_REC.Contract_mod#
               || CHR (9)
               || ' '
               || CHR (9)
               || QTY_CANC_REC.CONTRACT_MOD_SUBTOTAL;


            v_count := v_count + 1;
         END LOOP;

         SELECT   COUNT ( * )
           INTO   v_hold_cnt
           FROM   prism_pr_delphi_po_hold
          WHERE       NVL (PMO_NOTIFIED_FLAG, 'N') <> 'Y'
                  AND RECORD_TYPE = 'CHANGE IN QTY CANCEL'
                  AND CONTRACT_NUM = CONTRACT_INFO_ROW.CONTRACT_NUM;

         -- if the record exists in holding tank table and pmp notified flag is not equal to "Y" then notify those records to PMOs
         IF v_hold_cnt > 0
         THEN
            FOR EMAIL_LIST_ROW
            IN C_EMAIL_LIST (CONTRACT_INFO_ROW.CONTRACT_NUM)
            LOOP
               KITT_SEND_EMAIL (
                  'Surekha.CTR.Kandula@FAA.gov',
                  email_list_row.pmo_email, --V_EMAIL_LIST, --'Surekha.CTR.Kandula@FAA.gov',
                  'PMO attention is needed due to change in Delphi records for Contract#  '
                  || CONTRACT_INFO_ROW.CONTRACT_NUM,
                  v_msg
               );
            END LOOP;
         END IF;
      END LOOP;

      --commit;




      UPDATE   prism_pr_delphi_po_hold
         SET   PMO_NOTIFIED_FLAG = 'Y'
       WHERE       1 = 1
               AND RECORD_TYPE <> 'CHANGE IN QTY CANCEL'
               AND po_number = p_contract_num
               AND EXISTS
                     (SELECT   1
                        FROM   PRISM_PR_DELPHI_PO_HOLD
                       WHERE       NVL (PMO_NOTIFIED_FLAG, 'N') <> 'Y'
                               AND po_number = p_contract_num
                               AND RECORD_TYPE = 'CHANGE IN QTY CANCEL');
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR DELPHI PO',
            'Fail',
               'Failed to send an email notification'
            || '  '
            || 'Oracle Error msg'
            || SQLERRM
         );
         raise_application_error (
            -20022,
            'An error was encountered while sending an email notification- '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END p_changes_email_notification;

   ------XXXXXXXXXXXXXXXXXXXXXXXX
   PROCEDURE P_update_reqformod_prs
   IS
      CURSOR c_dup_rec_LSD
      IS
           SELECT   contract_num,
                    do_number,
                    award_li_num,
                    shipment#,
                    dist#,
                    COUNT ( * )
             FROM   prism_pr h
            WHERE   1 = 1
         GROUP BY   contract_num,
                    do_number,
                    award_li_num,
                    shipment#,
                    dist#
           HAVING   COUNT ( * ) > 1
         ORDER BY   contract_num,
                    do_number,
                    award_li_num,
                    shipment#,
                    dist#;

      CURSOR c_prism_pr (
         v_contract                 varchar2,
         v_do_num                   number,
         v_award_li                 number,
         v_ship                     number,
         v_dist                     number
      )
      IS
           SELECT   *
             FROM   prism_pr p
            WHERE       1 = 1
                    AND p.contract_num = v_contract
                    AND p.do_number = v_do_num
                    AND p.award_li_num = v_award_li
                    AND p.shipment# = v_ship
                    AND p.dist# = v_dist
         ORDER BY   award_li_num,
                    shipment#,
                    dist#,
                    pr_li_num;
   BEGIN
      FOR dup_rec_LSD_row IN c_dup_rec_LSD
      LOOP
         FOR prism_pr_row IN c_prism_pr (dup_rec_LSD_row.contract_num,
                                         dup_rec_LSD_row.do_number,
                                         dup_rec_LSD_row.award_li_num,
                                         dup_rec_LSD_row.shipment#,
                                         dup_rec_LSD_row.dist#)
         LOOP
            UPDATE   PRISM_PR_DELPHI_PO pd
               SET                        --EXTRACT_DATE            = SYSDATE,
                  PR = prism_pr_row.PR,
                     REQ_TYPE = prism_pr_row.REQ_TYPE,
                     PR_DESC = prism_pr_row.PR_DESC,
                     PR_LINEITEM_DESC = prism_pr_row.PR_LINEITEM_DESC,
                     REQUISITIONER = prism_pr_row.REQUISITIONER,
                     CONTRACT_NUM = prism_pr_row.CONTRACT_NUM,
                     PR_LI_NUM = prism_pr_row.PR_LI_NUM,
                     PR_DIST_AMOUNT = prism_pr_row.PR_DIST_AMOUNT,
                     AWARD_PROJECT# = prism_pr_row.AWARD_PROJECT#,
                     AWARD_TASK# = prism_pr_row.AWARD_TASK#,
                     AWARD_FUNDCODE = prism_pr_row.AWARD_FUNDCODE,
                     AWARD_BLI = prism_pr_row.AWARD_BLI,
                     AWARD_BUDGETYEAR = prism_pr_row.AWARD_BUDGETYEAR,
                     AWARD_OBJECT_CLASS = prism_pr_row.AWARD_OBJECT_CLASS,
                     AWARD_BPAC = prism_pr_row.AWARD_BPAC,
                     AWARD_EXPENDITUREORG = prism_pr_row.AWARD_EXPENDITUREORG,
                     AWARD_EXPENDITURETYPE =
                        prism_pr_row.AWARD_EXPENDITURETYPE,
                     AWARD_SGLACCT_CODE = prism_pr_row.AWARD_SGLACCT_CODE,
                     AWARD_EXPENDITUREDATE =
                        prism_pr_row.AWARD_EXPENDITUREDATE,
                     AWARD_ACCOUNT_CODE = prism_pr_row.award_account_code,
                     AWARD_LI_NUM = prism_pr_row.AWARD_LI_NUM,
                     shipment# = prism_pr_row.shipment#,
                     DIST# = prism_pr_row.DIST#,
                     NAME_POC = prism_pr_row.NAME_POC,
                     ORIGINATING_OFFICE_DATA =
                           prism_pr_row.ORIGINATING_OFFICE
                        || '/'
                        || prism_pr_row.ORIGINATION_OFFICE_NAME,
                     REQUISITION_DATE = prism_pr_row.REQUISITION_DATE,
                     CONSIGNEE_AND_DESTINATION =
                        prism_pr_row.CONSIGNEE_AND_DESTINATION,
                     DATES_REQUIRED = prism_pr_row.DATES_REQUIRED,
                     CONTRACT_AUTHORITY_FURNISHED =
                        prism_pr_row.CONTRACT_AUTHORITY_FURNISHED,
                     TYPE_OF_FUNDS = prism_pr_row.TYPE_OF_FUNDS,
                     EXPENDITURE_EXPIRATION_DATE =
                        prism_pr_row.EXPENDITURE_EXPIRATION_DATE,
                     FUND_DESCRIPTION = prism_pr_row.FUND_DESCRIPTION,
                     CONTRACT_MOD# = prism_pr_row.CONTRACT_MOD#
             WHERE       1 = 1
                     --and pd.charge_account = replace(prism_pr_row.award_account_code,'.0000000000.0000000000.0000000000.0000000000')
                     AND pd.DIST# = prism_pr_row.DIST#
                     AND pd.SHIPMENT# = prism_pr_row.SHIPMENT#
                     AND pd.AWARD_LI_NUM = prism_pr_row.AWARD_LI_NUM
                     AND pd.DO_NUMBER = prism_pr_row.do_number
                     AND pd.PO_NUMBER = prism_pr_row.CONTRACT_NUM;
         END LOOP;
      END LOOP;
   END P_update_reqformod_prs;

   --xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   -- procedure : P_AVOID_DUP_PRS_EXCEPTION
   -- Desc: Added this procedure to fix the  data for duplicate pr's  dustribution amount on  prism_pr table for JIRA Ticket-912
   -- Added the pr_Version columns on prism related tables and also add pr_version column on unique index to
   -- avoid unique constraint violation error.
   -- Created: Surekha Kandula
   -- Added : 24-OCT-2011

   --xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   PROCEDURE P_AVOID_DUP_PRS_EXCEPTION (p_contract_num varchar2)
   IS
      CURSOR c_dup_prs
      IS
           SELECT   contract_num,
                    DO_NUMBER,
                    AWARD_LI_NUM,
                    SHIPMENT#,
                    DIST#,
                    PR,
                    PR_LI_NUM,
                    REQ_TYPE,
                    CONTRACT_MOD#,
                    COUNT ( * )
             FROM   prism_pr
            WHERE   contract_num = p_contract_num
         GROUP BY   contract_num,
                    DO_NUMBER,
                    AWARD_LI_NUM,
                    SHIPMENT#,
                    DIST#,
                    PR,
                    PR_LI_NUM,
                    REQ_TYPE,
                    CONTRACT_MOD#
           HAVING   COUNT ( * ) > 1;
   BEGIN
      FOR DUP_PRS_ROW IN C_DUP_PRS
      LOOP
         UPDATE   prism_pr p
            SET   AWARD_DIST_OBLIG_AMT = 0
          WHERE       1 = 1
                  AND CONTRACT_NUM = DUP_PRS_ROW.CONTRACT_NUM
                  AND do_number = DUP_PRS_ROW.do_number
                  AND award_li_num = DUP_PRS_ROW.award_li_num
                  AND shipment# = DUP_PRS_ROW.shipment#
                  AND dist# = DUP_PRS_ROW.dist#
                  AND pr = DUP_PRS_ROW.pr
                  AND req_type = DUP_PRS_ROW.req_type
                  AND PR_VERSION IN
                           (SELECT   PR_VERSION
                              FROM   PRISM_PR_STAGE ps
                             WHERE       1 = 1
                                     AND ps.CONTRACT_NUM = p.CONTRACT_NUM
                                     AND ps.do_number = p.do_number
                                     AND ps.award_li_num = p.award_li_num
                                     AND ps.shipment# = p.shipment#
                                     AND ps.dist# = p.dist#
                                     AND ps.pr = p.pr
                                     AND ps.req_type = p.req_type
                                     AND ps.PR_DIST_COMMITTED_AMT = 0);
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAIL (
            'PRISM PR',
            'Fail',
            'Failed to update the prism_pr table to correct the award_dist_oblig_amt on prism_pr table to fix the duplicate prs exception data'
            || '  '
            || 'Oracle Error msg'
            || SQLERRM
         );
         raise_application_error (
            -20022,
            'An error was encountered while update the award_dist_oblig_amt in prism_pr table for duplicate prs exception '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_AVOID_DUP_PRS_EXCEPTION;
END PRISM_DELPHI_DATA_PKG; 
/
