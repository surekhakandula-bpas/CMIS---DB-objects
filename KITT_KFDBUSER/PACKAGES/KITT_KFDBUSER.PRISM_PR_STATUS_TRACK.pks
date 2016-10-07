DROP PACKAGE PRISM_PR_STATUS_TRACK;

CREATE OR REPLACE PACKAGE prism_pr_status_track
AS
   /******************************************************************************
      NAME:       prism_pr_status_track
      PURPOSE:    Capture the PR status and populate pr detail data for given PR and Contract number and also
                  If the PR is found in prism database then create PR Image PDF file.

      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        5/4/2011             1. Created this package.

    This software is developed as part of BPAS Contract with the FAA under
    the KITT Task Order.
    Major Revision History
    Num    Date          Source    Change Description
     1    02/29/2012    Email trail      Make XML response short
     2    03/01/2012    Email trail      Make response return 0,1
     3    03/02/2012    Sjawn mtg        Make response return 0,1,2
     4    03/03/2012    Sjawn mtg        Delete Username (user name defaulted to KITT USER )
     5    04/15/2012    Sjawn mtg        Add ReqSmrt Search functionality
   ******************************************************************************/

   PROCEDURE P_populate_pr_request_data (p_pr             IN     VARCHAR2,
                                         p_contract_num   IN     VARCHAR2,
                                         p_pr_user_id     IN     VARCHAR2,
                                         os_err              OUT VARCHAR2);

   PROCEDURE p_insert_pr_cover_sheet (p_pr             IN     VARCHAR2,
                                      p_contract_num   IN     VARCHAR2,
                                      os_err_msg          OUT VARCHAR2);

   PROCEDURE p_exist_pr_status_update;

   PROCEDURE p_exist_pr_status_update (p_pr IN VARCHAR2);

   PROCEDURE P_PR_TOT_AMT (p_pr IN VARCHAR2, os_err_msg OUT VARCHAR2);

   PROCEDURE p_update_expdate (p_pr IN VARCHAR2, os_err_msg OUT VARCHAR2);

   PROCEDURE P_update_pr_found_flag (p_pr         IN     VARCHAR2,
                                     os_err_msg      OUT VARCHAR2);

   PROCEDURE P_Insert_init_pr_cover_sheet (p_pr             IN     VARCHAR2,
                                           p_contract_num   IN     VARCHAR2,
                                           os_err_msg          OUT VARCHAR2);

   PROCEDURE p_non_released_route_hist (p_pr             IN     VARCHAR2,
                                        p_contract_num   IN     VARCHAR2,
                                        os_err_msg          OUT VARCHAR2);

   PROCEDURE p_released_route_hist (p_pr             IN     VARCHAR2,
                                    p_contract_num   IN     VARCHAR2,
                                    os_err_msg          OUT VARCHAR2);

   PROCEDURE p_update_pr_status;

   PROCEDURE P_JOB_EVENT_DETAILS (p_event_process_nm    VARCHAR2,
                                  p_event_module_nm     VARCHAR2,
                                  p_event_short_desc    VARCHAR2,
                                  p_event_long_desc     VARCHAR2);

   PROCEDURE p_refresh_prism_pr_image (p_pr             IN     VARCHAR2,
                                       p_contract_num   IN     VARCHAR2,
                                       os_err_msg          OUT VARCHAR2);

   PROCEDURE p_exist_pr_status_refresh_req;

   PROCEDURE p_insert_pre_pr_cover_sheet (p_contract_num       VARCHAR2,
                                          os_err_msg       OUT VARCHAR2);

   PROCEDURE p_pr_status_Track_main (p_pr IN VARCHAR2);
   PROCEDURE insert_pr_image_pdf( pr_num    VARCHAR2);

END prism_pr_status_track; 
/

DROP PACKAGE BODY PRISM_PR_STATUS_TRACK;

CREATE OR REPLACE PACKAGE BODY               prism_pr_status_track
AS
   /******************************************************************************
      NAME:       prism_pr_status_track
      PURPOSE:    Capture the PR status and populate pr detail data for given PR and Contract and also
                  If the PR is found in prism database then create PR Image PDF file.

      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        5/4/2011     Surekha Kandula 1. Created this package body.
   ******************************************************************************/


   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       P_populate_pr_request_data
      PURPOSE:    Populate PR and Contract data into KITT PR REQUEST Table
                  and call mail procedure on background session.

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE P_populate_pr_request_data (p_pr             IN     VARCHAR2,
                                         p_contract_num   IN     VARCHAR2,
                                         p_pr_user_id     IN     VARCHAR2,
                                         os_err              OUT VARCHAR2)
   IS
      v_count          NUMBER := 0;
      v_pr             VARCHAR2 (30) := p_pr;
      v_contract_num   VARCHAR2 (30) := p_contract_num;
      v_pr_status      VARCHAR2 (30);
      l_job1           NUMBER;
      v_job_desc       VARCHAR2 (4000);
   --os_err varchar2(3000);
   BEGIN
      --- store pl sql block in to a variable to use in dbms job to run dynamically
      v_job_desc :=
            'begin prism_pr_status_track.p_pr_status_Track_main('
         || CHR (39)
         || v_pr
         || CHR (39)
         || ');end;';

      -- Find the pr count for given pr in KITT_PR_REQUEST table
      SELECT   COUNT ( * )
        INTO   v_count
        FROM   KITT_PR_REQUEST
       WHERE   pr = v_pr;

      -- and contract_num = v_contract_num;

      IF V_COUNT = 0
      THEN
         -- insert data into KITT_PR_REQUEST table for given pr, contract_number and pr_user_id.
         INSERT INTO KITT_PR_REQUEST (pr,
                                      contract_num,
                                      pr_user_id,
                                      pr_request_date,
                                      PR_STATUS_BACK_FLAG,
                                      PR_JOB_STATUS,
                                      PR_AWARD_Flag)
           VALUES   (v_pr,
                     v_contract_num,
                     p_pr_user_id,
                     SYSDATE,
                     'N',
                     'Draft',
                     'N');

         COMMIT;

         -- Submit dbms job to run the process in background session
         --DBMS_JOB.submit (l_job1, v_job_desc); -- commented on 09-11-2013
           prism_pr_status_track.p_pr_status_Track_main(v_pr);
        -- COMMIT;
        
      ELSE
         -- Select the pr's in KITT_PR_REQUEST table where pr not found in prism database
         SELECT   COUNT ( * )
           INTO   v_count
           FROM   KITT_PR_REQUEST
          WHERE       pr = v_pr
                  AND contract_num = v_contract_num
                  AND NVL (PR_FOUND, 'N') = 'N';

         IF v_count <> 0
         THEN
            NULL;
         -- commented the below code per sjawn's request, if the pr not found in prism data base then it never found

         --          delete from KITT_PR_REQUEST where pr = v_pr;
         --
         --           insert into KITT_PR_REQUEST(pr, contract_num, pr_user_id, pr_request_date,PR_STATUS_BACK_FLAG, PR_JOB_STATUS )
         --                    values (v_pr,
         --                            v_contract_num,
         --                            p_pr_user_id,
         --                            sysdate,
         --                            'N',
         --                            'Draft');
         --          commit;

         -- dbms_job.submit( l_job1, v_job_desc );
         -- commit;

         ELSE
            -- select the PR in kitt pr request table where pr found status is "Y"
            SELECT   pr_status
              INTO   v_pr_status
              FROM   KITT_PR_REQUEST
             WHERE       pr = v_pr
                     AND contract_num = v_contract_num
                     AND PR_FOUND = 'Y';

            -- if the pr status is not in "Closed" then call the procedure to refresh the pr data in prism_pr_cover_sheet table
            IF v_pr_status NOT IN ('Closed')
            THEN
               p_exist_pr_status_update (v_pr);
            END IF;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         P_JOB_EVENT_DETAILS (
            'PRISM PR STATUS TRACK',
            'P_populate_pr_request_data',
            'Fail',
               'Failed to insert pr data into KITT_PR_REQUEST table  '
            || 'Oracle Error msg '
            || SQLERRM
         );
         os_err :=
            'Failed to insert pr data in KITT_PR_REQUEST table ' || SQLERRM;
   END P_populate_pr_request_data;

   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_insert_pr_cover_sheet
     PURPOSE:    insert PR detail data into prism_pr_cover_sheet table after find the PR in prism database
                 & update the pr stauts in kitt_pr_request table

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE p_insert_pr_cover_sheet (p_pr             IN     VARCHAR2,
                                      p_contract_num   IN     VARCHAR2,
                                      os_err_msg          OUT VARCHAR2)
   IS
      v_pr_status     VARCHAR2 (40);
      v_pr_found      VARCHAR2 (30);
      v_pr_dist_amt   NUMBER;

      -- select the pr and contract number for givin pr
      CURSOR c_prs_list
      IS
         SELECT   pr, contract_num
           FROM   kitt_pr_request
          WHERE   pr = p_pr;

      --PR not in (SELECT DISTINCT PR FROM prism_pr_cover_sheet WHERE PR_STATUS in ('Closed', 'Released'));


      -- select the pr detail data from prism view for given pr number
      CURSOR c_cuff_awds (
         v_pr                 VARCHAR2
      )
      IS
         SELECT   PR,
                  PR_STATUS,
                  REQ_TYPE,
                  PR_VERSION,
                  PR_STATUSDATE,
                  PR_DESC,
                  PR_LINEITEM_DESC,
                  REQUESTED_BY,
                  REQUESTED_PHONE_NO,
                  REQUISITIONER,
                  REQUISITIONER_INFO,
                  REQUISITION_DATE,
                  ORIGINATION_OFFICE,
                  ORIGINATION_OFFICE_NAME,
                  REQ_APPROVED_DATE,
                  REQ_DEL_LOC_NM,
                  REQ_DELIVERY_ADDR,
                  REQ_DELIVERY_CITY,
                  REQ_DELIVERY_STATE_ZIP,
                  REQ_DELIVERY_COUNTRY,
                  REQ_DELIVERY_DATE,
                  REQ_DELIVERY_AFTER_DATE,
                  GFE,
                  CONTRACT_NUM,
                  TOTAL_CONTRACT_OBLIGATION_AMT,
                  DO_NUM,
                  MOD_NUM,
                  PR_LI_NUM,
                  PR_LINE_STATUS,
                  -- PR_DIST_AMOUNT , --commented this field for sjawn's request to show proper amounts for de-oblig prs and added the below decode statement
                  PR_DIST_AMOUNT,
                  PR_DIST_COMMITTED_AMT,
                  PR_APPROVER_DATE,
                  PR_CERTIFIER_DATE,
                  PR_REVIEWER_DATE,
                  PR_PROJECT#,
                  PR_TASK#,
                  PR_EXPENDITURE_TYPE,
                  PR_EXPENDITURE_ORG,
                  PR_EXPENDITURE_DATE,
                  PR_FUND_CODE,
                  PR_BLI,
                  PR_BPAC,
                  PR_BUDGET_YEAR,
                  PR_OBJECT_CLASS,
                  PR_ACCOUNT_CODE,
                  PR_BUYER_NAME,
                  BUYER_ASSIGNDATE,
                     pr_PROJECT#
                  || '.'
                  || pr_TASK#
                  || '.'
                  || PR_EXPENDITURE_ORG
                  || '.'
                  || pr_object_class
                  || '.'
                  || pr_expenditure_date
                  || '.'
                  || pr_fund_code
                  || '.'
                  || pr_bli
                     pr_project_data
           FROM   V_TSOCUFF_AWDS@prism
          WHERE   1 = 1 AND pr = v_pr;                         --'AC-10-06122'
   BEGIN
      v_pr_found := NULL;
      v_pr_status := NULL;

      --P_JOB_EVENT_DETAILS('PR STATUS TRACK','P_INSERT_PR_COVER_SHEET','Info','PR Request process has started collecting PRs from KITT_PR_REQUEST table to query against from PRISM database at '|| to_char(sysdate,'MM/DD/YYYY HH:MM:SS'));
      -- capture the log info
      UPDATE   pr_image_log
         SET   prism_entry_ts = SYSDATE
       WHERE   pr = p_pr;

      FOR prs_list_row IN c_prs_list
      LOOP
         FOR cuff_awds_row IN c_cuff_awds (prs_list_row.pr)
         LOOP
            -- insert pr detail records into prism pr cover sheet from prism view
            INSERT INTO prism_pr_cover_sheet (              --PR_ENTERED_dATE,
                                                 PR,
                                                 PR_STATUS,
                                                 REQ_TYPE,
                                                 PR_VERSION,
                                                 PR_STATUSDATE,
                                                 PR_DESC,
                                                 PR_LINEITEM_DESC,
                                                 REQUESTED_BY,
                                                 REQUESTED_PHONE_NO,
                                                 REQUISITIONER,
                                                 REQUISITIONER_INFO,
                                                 REQUISITION_DATE,
                                                 ORIGINATION_OFFICE,
                                                 ORIGINATION_OFFICE_NAME,
                                                 REQ_APPROVED_DATE,
                                                 REQ_DEL_LOC_NM,
                                                 REQ_DELIVERY_ADDR,
                                                 REQ_DELIVERY_CITY,
                                                 REQ_DELIVERY_STATE_ZIP,
                                                 REQ_DELIVERY_COUNTRY,
                                                 REQ_DELIVERY_DATE,
                                                 REQ_DELIVERY_AFTER_DATE,
                                                 GFE,
                                                 CONTRACT_NUM,
                                                 TOTAL_CONTRACT_OBLIGATION_AMT,
                                                 DO_NUM,
                                                 MOD_NUM,
                                                 PR_LI_NUM,
                                                 PR_LINE_STATUS,
                                                 PR_DIST_AMOUNT,
                                                 PR_DIST_COMMITTED_AMT,
                                                 PR_APPROVER_DATE,
                                                 PR_CERTIFIER_DATE,
                                                 PR_REVIEWER_DATE,
                                                 PR_PROJECT#,
                                                 PR_TASK#,
                                                 PR_EXPENDITURE_TYPE,
                                                 PR_EXPENDITURE_ORG,
                                                 PR_EXPENDITURE_DATE,
                                                 PR_FUND_CODE,
                                                 PR_BLI,
                                                 PR_BPAC,
                                                 PR_BUDGET_YEAR,
                                                 PR_OBJECT_CLASS,
                                                 PR_ACCOUNT_CODE,
                                                 PR_BUYER_NAME,
                                                 BUYER_ASSIGNDATE,
                                                 --  PR_flag,
                                                 created_by,
                                                 created_date,
                                                 pr_project_data
                       )
              VALUES   (                                    -- trunc(sysdate),
                           cuff_awds_row.PR,
                           cuff_awds_row.PR_STATUS,
                           cuff_awds_row.REQ_TYPE,
                           cuff_awds_row.PR_VERSION,
                           cuff_awds_row.PR_STATUSDATE,
                           cuff_awds_row.PR_DESC,
                           cuff_awds_row.PR_LINEITEM_DESC,
                           cuff_awds_row.REQUESTED_BY,
                           cuff_awds_row.REQUESTED_PHONE_NO,
                           cuff_awds_row.REQUISITIONER,
                           cuff_awds_row.REQUISITIONER_INFO,
                           cuff_awds_row.REQUISITION_DATE,
                           cuff_awds_row.ORIGINATION_OFFICE,
                           cuff_awds_row.ORIGINATION_OFFICE_NAME,
                           cuff_awds_row.REQ_APPROVED_DATE,
                           cuff_awds_row.REQ_DEL_LOC_NM,
                           cuff_awds_row.REQ_DELIVERY_ADDR,
                           cuff_awds_row.REQ_DELIVERY_CITY,
                           cuff_awds_row.REQ_DELIVERY_STATE_ZIP,
                           cuff_awds_row.REQ_DELIVERY_COUNTRY,
                           cuff_awds_row.REQ_DELIVERY_DATE,
                           cuff_awds_row.REQ_DELIVERY_AFTER_DATE,
                           cuff_awds_row.GFE,
                           p_CONTRACT_NUM,
                           cuff_awds_row.TOTAL_CONTRACT_OBLIGATION_AMT,
                           cuff_awds_row.DO_NUM,
                           cuff_awds_row.MOD_NUM,
                           cuff_awds_row.PR_LI_NUM,
                           cuff_awds_row.PR_LINE_STATUS,
                           --added this to show correct amount for reqformod pr's on APR 2012
                           DECODE (cuff_awds_row.REQ_TYPE,
                                   'REQUISITION',
                                   cuff_awds_row.PR_DIST_AMOUNT,
                                   cuff_awds_row.PR_DIST_COMMITTED_AMT),
                           --cuff_awds_row.PR_DIST_AMOUNT ,
                           cuff_awds_row.PR_DIST_COMMITTED_AMT,
                           cuff_awds_row.PR_APPROVER_DATE,
                           cuff_awds_row.PR_CERTIFIER_DATE,
                           cuff_awds_row.PR_REVIEWER_DATE,
                           cuff_awds_row.PR_PROJECT#,
                           cuff_awds_row.PR_TASK#,
                           cuff_awds_row.PR_EXPENDITURE_TYPE,
                           cuff_awds_row.PR_EXPENDITURE_ORG,
                           cuff_awds_row.PR_EXPENDITURE_DATE,
                           cuff_awds_row.PR_FUND_CODE,
                           cuff_awds_row.PR_BLI,
                           cuff_awds_row.PR_BPAC,
                           cuff_awds_row.PR_BUDGET_YEAR,
                           cuff_awds_row.PR_OBJECT_CLASS,
                           cuff_awds_row.PR_ACCOUNT_CODE,
                           cuff_awds_row.PR_BUYER_NAME,
                           cuff_awds_row.BUYER_ASSIGNDATE,
                           'System',
                           SYSDATE,
                           cuff_awds_row.pr_project_data
                       );



            v_pr_status := cuff_awds_row.pr_status;
         END LOOP;

         /*update kitt_pr_request table with the pr status for given pr after
           sucessfully inserted pr detail data into prism pr cover sheet table*/
         UPDATE   kitt_pr_request R
            SET   PR_STATUS = v_pr_status
          WHERE   PR = prs_list_row.pr;
      END LOOP;

      -- capture the date and time in pr image log table after pr inserted in prism pr cover sheet table
      UPDATE   pr_image_log
         SET   prism_return_ts = SYSDATE
       WHERE   pr = p_pr;

      --P_JOB_EVENT_DETAILS('PR STATUS TRACK','P_INSERT_PR_COVER_SHEET','Info','PR Request process has completed collecting PRs data from PRISM database at '|| to_char(sysdate,'MM/DD/YYYY HH:MM:SS'));
      os_err_msg := NULL;
   -- commit;

   EXCEPTION
      WHEN OTHERS
      THEN
         P_JOB_EVENT_DETAILS (
            'PR STATUS TRACK',
            'P_INSERT_PR_COVER_SHEET',
            'Fail',
            'Failed to load prism pr data from cuff_awds_view into prism_pr_cover_sheet table '
            || 'Oracle Error msg '
            || SQLERRM
         );
         os_err_msg :=
            'Failed to insert pr data in Prism_pr_request table ' || SQLERRM;

         ROLLBACK;
   END p_insert_pr_cover_sheet;



   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_exist_pr_status_update
     PURPOSE:     collect the PR's from KITT_PR_REQUEST table for give contract and verify the PR AWARD_FLAG
                  is not equal to 'N' and refresh the data into prism_pr_cover_sheet table.
                  This Procedure is scheduled to run the DBMS Job every day at 8 AM

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

   PROCEDURE p_exist_pr_status_update
   IS
      i                  VARCHAR2 (4000);
      v_pr_status        VARCHAR2 (30);
      v_pr_total         NUMBER;
      os_err_msg         VARCHAR2 (600);
      v_pr_data_source   VARCHAR2 (20);

      -- select the list of contracts from contract_info table
      CURSOR c_contract_list
      IS
         SELECT   contract_num
           FROM   contract_info
          WHERE   contract_num in ('DTFAWA-11-C-00003');

      -- select the list of pr's for given contract from kitt pr request table
      CURSOR c_kitt_pr_request (
         v_contract_num                 VARCHAR2
      )
      IS
         SELECT   pr, contract_num
           FROM   KITT_PR_REQUEST
          WHERE       1 = 1
                  AND pr_award_flag = 'N'
                  AND contract_num = v_contract_num;
   -- commented below conditions on 04/19/2011 for  Timothy Bowders request to update all the prs
   -- until it's get awarded
   -- and pr_status not in ('Closed')
   --and pr not in (select distinct pr from prism_pr);
   BEGIN
      FOR contract_list_row IN c_contract_list
      LOOP
         FOR kitt_pr_request_row
         IN c_kitt_pr_request (contract_list_row.contract_num)
         LOOP
            BEGIN
               /* store the pr data source field  in a variable for given pr from cover sheet table before refresh the cover sheet table       */
               SELECT   DISTINCT pr_data_source
                 INTO   v_pr_data_source
                 FROM   prism_pr_cover_sheet
                WHERE   pr = kitt_pr_request_row.pr;
            EXCEPTION
               WHEN OTHERS
               THEN
                  v_pr_data_source := NULL;
            END;

            -- delete for given pr from prism_pr_cover_sheet table before the refresh
            DELETE FROM   prism_pr_cover_sheet
                  WHERE   pr = kitt_pr_request_row.pr
                          AND contract_num = kitt_pr_request_row.contract_num;

            -- insert the PR latest data into prism_pr_cover_sheet
            p_insert_pr_cover_sheet (kitt_pr_request_row.pr,
                                     kitt_pr_request_row.contract_num,
                                     os_err_msg);

            --  update pr data source into prism_pr_cover_sheet
            UPDATE   prism_pr_cover_sheet
               SET   pr_data_source = v_pr_data_source
             WHERE   pr = kitt_pr_request_row.pr;


            -- call the below procedures to update the prism pr cover sheet table for KITT value added fields
            P_PR_TOT_AMT (kitt_pr_request_row.pr, os_err_msg);
            p_update_expdate (kitt_pr_request_row.pr, os_err_msg);
            p_non_released_route_hist (kitt_pr_request_row.pr,
                                       kitt_pr_request_row.contract_num,
                                       os_err_msg);
            p_released_route_hist (kitt_pr_request_row.pr,
                                   kitt_pr_request_row.contract_num,
                                   os_err_msg);


            -- update pr_pr_cover_sheet created date  field with pr request date
            UPDATE   prism_pr_cover_sheet
               SET   created_date =
                        (SELECT   pr_request_Date
                           FROM   kitt_pr_Request
                          WHERE   pr = kitt_pr_request_row.pr),
                     modified_by = 'System',
                     modified_Date = SYSDATE
             WHERE   pr = kitt_pr_request_row.pr;

            -- update kitt_pr_Request table with the pr_award_flag field
            UPDATE   kitt_pr_request
               SET   pr_award_flag = 'Y'
             WHERE       1 = 1
                     AND pr = kitt_pr_request_row.pr
                     AND pr_status = 'Closed'
                     AND pr IN
                              (SELECT   DISTINCT pr
                                 FROM   prism_pr
                                WHERE   contract_num =
                                           kitt_pr_request_row.contract_num
                                        AND pr = kitt_pr_request_row.pr);


            -- update latest pr status in kitt_pr_request table
            UPDATE   KITT_PR_REQUEST
               SET   pr_status =
                        (SELECT   DISTINCT pr_status
                           FROM   prism_pr_cover_sheet
                          WHERE   pr = kitt_pr_request_row.PR)
             WHERE   pr = kitt_pr_request_row.PR;

            COMMIT;

            -- If kitt_pr_request_row.contract_num <> 'DTFA01-02-C-A0016' then
            -- kfdbdev2 server
           -- i:=sys.utl_http.request('http://172.30.33.34:8500/primage/generate_pdf.cfm?pr='||kitt_pr_request_row.pr );
            --coldfusion server
            --i :=sys.UTL_HTTP.request('http://10.132.33.3:8500/kfdbweb/devt/ws/cf/web/cfmr/primage/generate_pdf.cfm?pr='|| kitt_pr_request_row.pr);

            p_refresh_PRISM_PR_IMAGE (kitt_pr_request_row.pr,
                                      kitt_pr_request_row.contract_num,
                                      os_err_msg);
         -- end if;

         END LOOP;
      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         --P_JOB_EVENT_DETAILS('PR STATUS TRACK','p_exist_pr_status_update','Fail','Failed to update pr latest status data in prism_pr_cover_sheet table  '|| 'Oracle Error msg '|| SQLERRM);
         os_err_msg :=
            'Failed to update pr latest status data in prism_pr_cover_sheet table '
            || SQLERRM;

         ROLLBACK;
   END p_exist_pr_status_update;



   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_exist_pr_status_update
     PURPOSE:     collect the PR's from KITT_PR_REQUEST table for give contract and given PR and verify the PR AWARD_FLAG
                  is not equal to 'N' and refresh the data into prism_pr_cover_sheet table.

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE p_exist_pr_status_update (p_pr VARCHAR2)
   IS
      i                  VARCHAR2 (4000);
      v_pr_status        VARCHAR2 (30);
      v_pr_total         NUMBER;
      os_err_msg         VARCHAR2 (600);
      v_pr_data_source   VARCHAR2 (20);

      CURSOR c_kitt_pr_request
      IS
         SELECT   pr, contract_num
           FROM   KITT_PR_REQUEST
          WHERE   1 = 1 AND pr_award_flag = 'N' --and contract_num ='DTFA01-02-C-A0016'
                  AND pr = p_pr;
   -- commented below conditions on 04/19/2011 for  Timothy Bowders request to update all the prs
   -- until it's get awarded
   -- and pr_status not in ('Closed')
   --and pr not in (select distinct pr from prism_pr);
   BEGIN
      FOR kitt_pr_request_row IN c_kitt_pr_request
      LOOP
         BEGIN
            SELECT   DISTINCT pr_data_source
              INTO   v_pr_data_source
              FROM   prism_pr_cover_sheet
             WHERE   pr = kitt_pr_request_row.pr;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_pr_data_source := NULL;
         END;

         -- delete for given pr from prism_pr_cover_sheet table before the refresh
         DELETE FROM   prism_pr_cover_sheet
               WHERE   pr = kitt_pr_request_row.pr
                       AND contract_num = kitt_pr_request_row.contract_num;

         -- insert the PR latest data into prism_pr_cover_sheet
         p_insert_pr_cover_sheet (kitt_pr_request_row.pr,
                                  kitt_pr_request_row.contract_num,
                                  os_err_msg);

         --  update pr data source into prism_pr_cover_sheet
         UPDATE   prism_pr_cover_sheet
            SET   pr_data_source = v_pr_data_source
          WHERE   pr = kitt_pr_request_row.pr;


         -- IF os_err_msg is null then
         P_PR_TOT_AMT (kitt_pr_request_row.pr, os_err_msg);
         p_update_expdate (kitt_pr_request_row.pr, os_err_msg);
         p_non_released_route_hist (kitt_pr_request_row.pr,
                                    kitt_pr_request_row.contract_num,
                                    os_err_msg);
         p_released_route_hist (kitt_pr_request_row.pr,
                                kitt_pr_request_row.contract_num,
                                os_err_msg);


         -- update pr_pr_cover_sheet created date  field with pr request date
         UPDATE   prism_pr_cover_sheet
            SET   created_date =
                     (SELECT   pr_request_Date
                        FROM   kitt_pr_Request
                       WHERE   pr = kitt_pr_request_row.pr),
                  modified_by = 'System',
                  modified_Date = SYSDATE
          WHERE   pr = kitt_pr_request_row.pr;

         -- update kitt_pr_Request table with the pr_award_flag field
         UPDATE   kitt_pr_request
            SET   pr_award_flag = 'Y'
          WHERE       1 = 1
                  AND pr = kitt_pr_request_row.pr
                  AND pr_status = 'Closed'
                  AND pr IN
                           (SELECT   DISTINCT pr
                              FROM   prism_pr
                             WHERE   contract_num =
                                        kitt_pr_request_row.contract_num
                                     AND pr = kitt_pr_request_row.pr);


         -- update latest pr status in kitt_pr_request table
         UPDATE   KITT_PR_REQUEST
            SET   pr_status =
                     (SELECT   DISTINCT pr_status
                        FROM   prism_pr_cover_sheet
                       WHERE   pr = kitt_pr_request_row.PR)
          WHERE   pr = kitt_pr_request_row.PR;

         COMMIT;

         -- If kitt_pr_request_row.contract_num <> 'DTFA01-02-C-A0016' then
         -- kfdbdev2 server
         i:=sys.utl_http.request('http://172.30.33.34:8500/primage/generate_pdf.cfm?pr='||kitt_pr_request_row.pr );
         --coldfusion server
        -- i := sys.UTL_HTTP.request('http://10.132.33.3:8500/kfdbweb/devt/ws/cf/web/cfmr/primage/generate_pdf.cfm?pr='
                                -- || kitt_pr_request_row.pr);
         p_refresh_PRISM_PR_IMAGE (kitt_pr_request_row.pr,
                                   kitt_pr_request_row.contract_num,
                                   os_err_msg);
      -- end if;

      --ELSE

      --ROLLBACK;

      --END IF;





      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         --P_JOB_EVENT_DETAILS('PR STATUS TRACK','p_exist_pr_status_update','Fail','Failed to update pr latest status data in prism_pr_cover_sheet table  '|| 'Oracle Error msg '|| SQLERRM);
         os_err_msg :=
            'Failed to update pr latest status data in prism_pr_cover_sheet table '
            || SQLERRM;

         ROLLBACK;
   END p_exist_pr_status_update;

   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       P_PR_TOT_AMT
     PURPOSE:     Collect the sum of PR DIST AMOUNT and update into TOTAL_ESTIMATED_COST field
                  in prism_pr_cover_sheet table.

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE P_PR_TOT_AMT (p_pr IN VARCHAR2, os_err_msg OUT VARCHAR2)
   IS
      v_pr_tot_amt   NUMBER;
   BEGIN
      -- select the sum of pr dist amount from prism pr cover sheet table for given pr
      SELECT   SUM (pr_dist_amount)
        INTO   v_pr_tot_amt
        FROM   prism_pr_cover_sheet
       WHERE   pr = p_pr;

      IF v_pr_tot_amt IS NOT NULL
      THEN
         UPDATE   prism_pr_cover_sheet
            SET   TOTAL_ESTIMATED_COST = v_pr_tot_amt
          WHERE   pr = p_pr;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         P_JOB_EVENT_DETAILS (
            'PR STATUS TRACK',
            'P_PR_TOT_AMT',
            'Fail',
            'Failed to update pr total amount data in prism_pr_cover_sheet table '
            || 'Oracle Error msg '
            || SQLERRM
         );
         os_err_msg :=
            'Failed to update pr total amount data in prism_pr_cover_sheet table '
            || 'Oracle Error msg '
            || SQLERRM;
         ROLLBACK;
   END P_PR_TOT_AMT;



   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_update_expdate
     PURPOSE:     update value added columns (obligation_expiration_date, Fund_type &
                  expenditure_expiration_date) in prism_pr_cover_sheet table

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE p_update_expdate (p_pr IN VARCHAR2, os_err_msg OUT VARCHAR2)
   IS
      CURSOR c_oblig_exp_date
      IS
         -- select the expiration date based on accoun code for give pr
         SELECT   pr_account_code,
                  pr,
                  pr_li_num,
                  DECODE (SUBSTR (pr_account_code, 3, 1),
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
           FROM   prism_pr_cover_sheet
          WHERE   pr = p_pr;
   BEGIN
      FOR oblig_exp_date_row IN c_oblig_exp_date
      LOOP
         --update prism pr cover shee table with obligation expiration date for give pr in prism pr cover sheet table
         UPDATE   prism_pr_cover_sheet
            SET   obligation_expiration_date =
                     oblig_exp_date_row.obligation_exp_date
          WHERE   pr_account_code = oblig_exp_date_row.pr_account_code
                  AND pr = oblig_exp_date_row.pr;
      END LOOP;

      -- update the prism pr cover sheet table with the fund type for give pr
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'ARRA'
       WHERE       SUBSTR (pr_account_code, 6, 2) = ('AS')
               AND SUBSTR (pr_account_code, 3, 1) <> 'X'
               AND pr = p_pr;

      -- OPS (pr_account_code 4th and 5th charactors should be '01')
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'OPS'
       WHERE       SUBSTR (pr_account_code, 4, 2) = ('01')
               AND SUBSTR (pr_account_code, 6, 2) <> ('AS')
               AND SUBSTR (pr_account_code, 3, 1) <> 'X'
               AND pr = p_pr;

      --GRANTS (pr_account_code 4th and 5th charactors should be '81')
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'GRANTS'
       WHERE       SUBSTR (pr_account_code, 4, 2) = ('81')
               AND SUBSTR (pr_account_code, 6, 2) <> ('AS')
               AND SUBSTR (pr_account_code, 3, 1) <> 'X'
               AND pr = p_pr;

      --F&E (pr_account_code 4th and 5th charactors should be '82')
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'F&E'
       WHERE       SUBSTR (pr_account_code, 4, 2) = ('82')
               AND SUBSTR (pr_account_code, 6, 2) <> ('AS')
               AND SUBSTR (pr_account_code, 3, 1) <> 'X'
               AND SUBSTR (pr_account_code, 6, 1) <> ('W')
               AND pr = p_pr;

      --PCB&T (pr_account_code 4th and 5th 6th charactors should be '82W')
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'PCB&T'
       WHERE       SUBSTR (pr_account_code, 4, 3) = ('82W')
               AND SUBSTR (pr_account_code, 6, 2) <> ('AS')
               AND SUBSTR (pr_account_code, 3, 1) <> 'X'
               AND SUBSTR (pr_account_code, 6, 1) = ('W')
               AND pr = p_pr;

      --RE&D (pr_account_code 4th and 5th charactors should be '88')
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'RE&D'
       WHERE       SUBSTR (pr_account_code, 4, 2) = ('88')
               AND SUBSTR (pr_account_code, 6, 2) <> ('AS')
               AND SUBSTR (pr_account_code, 3, 1) <> 'X'
               AND pr = p_pr;

      --REIMB (pr_account_code 4th,5th & 6th charactors should be '82R')
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'REIMB'
       WHERE       SUBSTR (pr_account_code, 4, 3) = ('82R')
               AND SUBSTR (pr_account_code, 6, 2) <> ('AS')
               AND SUBSTR (pr_account_code, 3, 1) <> 'X'
               AND pr = p_pr;

      --FRANCH (pr_account_code 3rd charactor should be 'X')
      UPDATE   prism_pr_cover_sheet
         SET   FUND_TYPE = 'FRANCH'
       WHERE       SUBSTR (pr_account_code, 3, 1) = ('X')
               AND SUBSTR (pr_account_code, 6, 2) <> ('AS')
               AND pr = p_pr;

      COMMIT;


      --Update EXPENDITURE EXPIRATION DATE field in prism pr cover sheet table for give pr

      -- expire 2013 ( 3rd charactor should be 8)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2013'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('8') AND pr = p_pr;

      -- expire 2014 ( 3rd charactor should be 9)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2014'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('9') AND pr = p_pr;

      -- expire 2015 ( 3rd charactor should be 0)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2015'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('0') AND pr = p_pr;

      -- expire 2016 ( 3rd charactor should be 1)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2016'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('1') AND pr = p_pr;

      -- expire 2017 ( 3rd charactor should be 2)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2017'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('2') AND pr = p_pr;

      -- expire 2018 ( 3rd charactor should be 3)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2018'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('3') AND pr = p_pr;

      -- expire 2019 ( 3rd charactor should be 4)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2019'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('4') AND pr = p_pr;

      -- expire 2020 ( 3rd charactor should be 5)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2020'
       WHERE   SUBSTR (pr_account_code, 3, 1) = ('5') AND pr = p_pr;


      -- expire 2099 ( 3rd charactor should not be 8,9,0,1)
      UPDATE   prism_pr_cover_sheet
         SET   expenditure_expiration_date = '30-SEP-2099'
       WHERE   SUBSTR (pr_account_code, 3, 1) IN ('N', 'X') AND pr = p_pr;
   EXCEPTION
      WHEN OTHERS
      THEN
         P_JOB_EVENT_DETAILS (
            'PR STATUS TRACK',
            'P_UPDATE_EXP_DATE',
            'Fail',
            'Failed to update value added vields on prism_pr_cover_sheet table'
            || 'Oracle Error msg '
            || SQLERRM
         );
         ROLLBACK;
   END p_update_expdate;



   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       P_UPDATE_PR_FOUND_FLAG
      PURPOSE:    Update PR Found flag in KIT_PR_REQUEST Table for given PR.

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

   PROCEDURE P_UPDATE_PR_FOUND_FLAG (p_pr         IN     VARCHAR2,
                                     os_err_msg      OUT VARCHAR2)
   IS
      V_PR_COUNT   NUMBER;
   BEGIN
      SELECT   COUNT ( * )
        INTO   V_PR_COUNT
        FROM   prism_pr_cover_sheet
       WHERE   PR = P_PR;

      IF V_PR_COUNT <> 0
      THEN
         -- update the pr found field with 'N' in kitt pr request table if the pr found in prism pr cover sheet table
         UPDATE   KITT_PR_REQUEST
            SET   PR_FOUND = 'Y'
          WHERE   PR = P_PR;
      ELSIF V_PR_COUNT = 0
      THEN
         -- update the pr found field with 'N' in kitt pr request table if the pr not found in prism pr cover sheet table
         UPDATE   KITT_PR_REQUEST
            SET   PR_FOUND = 'N'
          WHERE   PR = P_PR;
      END IF;

      --commit;
      os_err_msg := NULL;
   EXCEPTION
      WHEN OTHERS
      THEN
         P_JOB_EVENT_DETAILS (
            'PR STATUS TRACK',
            'P_UPDATE_PR_FOUND_FLAG',
            'Fail',
               'Failed to update the pr_found flag in KITT_PR_REQUEST table '
            || 'Oracle Error msg '
            || SQLERRM
         );
         os_err_msg :=
               'Failed to update pr_found flag in KITT_PR_REQUEST table '
            || 'Oracle Error msg '
            || SQLERRM;

         ROLLBACK;
   END P_UPDATE_PR_FOUND_FLAG;

   -- Insert data into initial_pr_cover_sheet table. This procedure is not beeing used.
   PROCEDURE P_Insert_init_pr_cover_sheet (p_pr             IN     VARCHAR2,
                                           p_contract_num   IN     VARCHAR2,
                                           os_err_msg          OUT VARCHAR2)
   IS
    begin
      null;
   end P_Insert_init_pr_cover_sheet;  
   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_non_released_route_hist
     PURPOSE:     update non released pr's routing information on prism_pr_cover_sheet table from PRISM View

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE p_non_released_route_hist (p_pr             IN     VARCHAR2,
                                        p_contract_num   IN     VARCHAR2,
                                        os_err_msg          OUT VARCHAR2)
   IS
      --cursor c_contract_info is
      --select distinct contract_num
      --from contract_info;
      --where contract_num ='DTFAWA-08-C-00009';

      -- select the pr and contract number for given pr in kitt pr request table if the pr status is not 'in Released or Closed.
      CURSOR C1
      IS
         SELECT   pr, contract_num
           FROM   kitt_pr_request
          WHERE   1 = 1 AND pr = p_pr --AND pr not in (select pr from prism_pr_cover_sheet where pr_status in ('Closed','Released'))
                  AND pr_status NOT IN ('Released', 'Closed');

      --select the pr routing info for given pr's which is not closed and released
      CURSOR c_route (
         v_pr                 VARCHAR2
      )
      IS
         SELECT   DISTINCT PRNUM,
                           Reviewer_Name,
                           Route_Role,
                           In_Date
           FROM   v_pr_route_det@prism
          WHERE   1 = 1
                  AND status NOT IN
                           ('Cancelled Route',
                            'Ready to send',
                            'Approved',
                            'Reviewed')                          -- 'Approved'
                  AND route_role IN
                           ('Approver', 'Fund Certifier', 'Misc Review')
                  AND out_date IS NULL
                  AND in_date IS NOT NULL
                  AND in_date IN
                           (SELECT   MIN (in_date)
                              FROM   v_pr_route_det@prism
                             WHERE   1 = 1
                                     AND status NOT IN
                                              ('Cancelled Route',
                                               'Ready to send',
                                               'Approved',
                                               'Reviewed')       --'Approved',
                                     AND route_role IN
                                              ('Approver',
                                               'Fund Certifier',
                                               'Misc Review')
                                     AND out_date IS NULL
                                     AND prnum = v_pr)
                  AND prnum = v_pr;                            --'AC-08-02158'

      --and Reviewer_Name='Cambra, Richard G'

      v_pr_count   NUMBER;
   BEGIN
      --for row_contract_info in c_contract_info loop

      FOR c_row IN c1
      LOOP
         FOR c_route_row IN c_route (c_row.pr)
         LOOP
            BEGIN
               --update prism pr cover sheet table with the routing info for given pr
               UPDATE   prism_pr_cover_sheet
                  SET   modified_date = SYSDATE,
                        modified_by = 'System',
                        prism_pr_location = C_Route_Row.Reviewer_Name,
                        prism_pr_route_role = C_Route_Row.Route_Role,
                        prism_pr_location_date = C_Route_Row.In_Date
                WHERE   Pr = C_Row.Pr;
            EXCEPTION
               WHEN OTHERS
               THEN
                  DBMS_OUTPUT.put_line (
                     'exception for pr cover sheet update ' || SQLERRM
                  );
            END;
         END LOOP;
      END LOOP;
   --end loop;
   --commit;

   EXCEPTION
      WHEN OTHERS
      THEN
         P_JOB_EVENT_DETAILS (
            'PR STATUS TRACK',
            'P_NON_RELEASED_ROUTE_HIST',
            'Fail',
            'Failed to update non released routing history info on prism_pr_cover_sheet table'
            || 'Oracle Error msg '
            || SQLERRM
         );
         ROLLBACK;
   END p_non_released_route_hist;

   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_released_route_hist
     PURPOSE:     update released pr's routing information on prism_pr_cover_sheet table from PRISM View

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE p_released_route_hist (p_pr             IN     VARCHAR2,
                                    p_contract_num   IN     VARCHAR2,
                                    os_err_msg          OUT VARCHAR2)
   IS
      --cursor c_contract_info is
      --select distinct contract_num
      --from contract_info;
      --where contract_num ='DTFAWA-11-C-00003' ;--'DTFAWA-08-C-00009';

      --select the pr , contract number from kitt pr cover sheet table for given PR if the pr status is released
      CURSOR C1
      IS
         SELECT   DISTINCT pr, contract_num
           FROM   kitt_pr_request
          WHERE   1 = 1 AND pr = p_pr --AND pr in (select distinct pr from initial_pr_cover_sheet where Pr_Router_Name is not null )
                 AND pr_status in(  'Released','Closed');

      --and contract_num =p_contract_num;
      --and pr='WA-11-09436';

      -- select the pr reviewer name and and dates from prism view for given pr if the route role is 'Fund Certifier'
      CURSOR c_route (
         v_pr                 VARCHAR2
      )
      IS
         SELECT   DISTINCT PRNUM,
                           Reviewer_Name,
                           Route_Role,
                           In_Date
           FROM   v_pr_route_det@prism
          WHERE       1 = 1
                  AND status = 'Approved'
                  AND route_role IN ('Fund Certifier')
                  AND out_date IN
                           (SELECT   MAX (out_date)
                              FROM   v_pr_route_det@prism
                             WHERE       1 = 1
                                     AND status = 'Approved'
                                     AND route_role IN ('Fund Certifier')
                                     AND prnum = v_pr)
                  AND prnum = v_pr;                            --'AC-08-02158'


      v_pr_count   NUMBER;
   BEGIN
      --for row_contract_info in c_contract_info loop

      FOR c_row IN c1
      LOOP
         FOR c_route_row IN c_route (c_row.pr)
         LOOP
            --dbms_output.put_line('else if the pr count is not zero then ' ||c_row.pr);
            BEGIN
               -- update prism pr cover sheet table with the routing information for given pr
               UPDATE   prism_pr_cover_sheet
                  SET   modified_date = SYSDATE,
                        modified_by = 'System',
                        prism_pr_location = C_Route_Row.Reviewer_Name,
                        prism_pr_route_role = C_Route_Row.Route_Role,
                        prism_pr_location_date = C_Route_Row.In_Date
                WHERE   Pr = C_Row.Pr;
            --and Contract_Num = c_row.contract_num;

            EXCEPTION
               WHEN OTHERS
               THEN
                  DBMS_OUTPUT.put_line (
                     'exception for pr cover sheet update ' || SQLERRM
                  );
            END;
         END LOOP;
      END LOOP;
   --end loop;
   --commit;

   EXCEPTION
      WHEN OTHERS
      THEN
         P_JOB_EVENT_DETAILS (
            'PR STATUS TRACK',
            'P_RELEASED_ROUTE_HIST',
            'Fail',
            'Failed to update released routing history info on prism_pr_cover_sheet table'
            || 'Oracle Error msg '
            || SQLERRM
         );
         ROLLBACK;
   END p_released_route_hist;

   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_update_pr_status
     PURPOSE:     Collect all Released PR's and verify the PR in PRISM database and update the PR status if the PR is not in Released status.

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE p_update_pr_status
   IS
      CURSOR c_pr_status
      IS
         SELECT   DISTINCT pr
           FROM   prism_pr_cover_sheet
          WHERE   pr_status = 'Rleased';

      CURSOR c_prism_pr_status (v_pr VARCHAR2)
      IS
         SELECT   pr_status, pr
           FROM   V_TSOCUFF_AWDS@prism
          WHERE   1 = 1 AND pr_status <> 'Released' AND pr = v_pr; --'AC-10-06122'
   BEGIN
      FOR row_pr_status IN c_pr_status
      LOOP
         FOR row_prism_pr_status IN c_prism_pr_status (row_pr_status.pr)
         LOOP
            BEGIN
               UPDATE   prism_pr_cover_sheet
                  SET   pr_status = row_prism_pr_status.pr_status
                WHERE   pr = row_prism_pr_status.pr;

               UPDATE   prism_pr_image
                  SET   pr_status = row_prism_pr_status.pr_status
                WHERE   pr = row_prism_pr_status.pr;
            END;
         --commit;

         END LOOP;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         --P_JOB_EVENT_DETAILS('PR STATUS TRACK','P_UPDATE_PR_STATUS','Fail','Failed to update pr_status in pr_image andprism_pr_cover_sheettable '|| 'Oracle Error msg '|| SQLERRM);
         ROLLBACK;
   END p_update_pr_status;

   /******************************************************************************
        NAME:       P_JOB_EVENT_DETAILS
        PURPOSE:    Capture event log of the process

        REVISIONS: 1.0
        Date:   2/29/2009
      ******************************************************************************/
   PROCEDURE P_JOB_EVENT_DETAILS (p_event_process_nm    VARCHAR2,
                                  p_event_module_nm     VARCHAR2,
                                  p_event_short_desc    VARCHAR2,
                                  p_event_long_desc     VARCHAR2)
   IS
      -- p_job_desc varchar2(300);
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      -- insert log info in prism delphi job event detail table for given input
      INSERT INTO PRISM_DELPHI_JOB_EVENT_DETAILS
        VALUES   (p_event_process_nm,
                  TRUNC (SYSDATE),
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
            'An error was encountered while populating data into PRISM_DELPHI_JOB_EVENT_DETAILs table - '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM
         );
   END P_JOB_EVENT_DETAILs;

   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_refresh_PRISM_PR_IMAGE
     PURPOSE:     Refresh PRISM_PR_IMAGE table with the summary data along with
                  PRISM PR IMAGE PDF  BLOB field

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
    PROCEDURE p_refresh_PRISM_PR_IMAGE (p_pr             IN     VARCHAR2,
                                       p_contract_num   IN     VARCHAR2,
                                       os_err_msg          OUT VARCHAR2)
   IS
      v_file_name   VARCHAR2 (20);
      v_pr_count    NUMBER;


      /*select the pr summary information from kitt_pr_Request and also value added columns
      from prism_pr_cover_Sheet table for given pr */
      CURSOR c_prism_cover_sheet
      IS
         SELECT   DISTINCT PC.pr,         
                           PC.contract_num,
                           PC.TOTAL_ESTIMATED_COST,
                           PC.FUND_TYPE,
                           PC.OBLIGATION_EXPIRATION_DATE,
                           PC.EXPENDITURE_EXPIRATION_DATE,
                           KPR.PR_USER_ID,
                           KPR.PR_REQUEST_DATE,
                           KPR.PR_FOUND,
                           KPR.PR_STATUS,
                           KPR.PR_STATUS_BACK_FLAG
           FROM   prism_pr_cover_Sheet PC, KITT_PR_REQUEST KPR    
           WHERE   PC.PR = KPR.PR
           AND KPR.CONTRACT_NUM = KPR.CONTRACT_NUM
           AND KPR.pr = p_pr;
           

   BEGIN
  
    -- call procedure to insert pr and pr image fields in prism_pr_image table
      --insert_pr_image_pdf(p_pr);    
         delete from prism_pr_image where pr = p_pr;
          commit;
        insert into prism_pr_image(pr) values (p_pr);
      
      FOR prism_cover_sheet_row IN c_prism_cover_sheet   LOOP
      
      -- dbms_output.put_line('before update')
            
        -- update the prism pr image table for KITT value added fields from kitt pr request table
         UPDATE   PRISM_PR_IMAGE
            SET   PR_TOTAL_ESTIMATED_COST =   prism_cover_sheet_row.TOTAL_ESTIMATED_COST,
                  FUND_TYPE = prism_cover_sheet_row.FUND_TYPE,
                  OBLIGATION_EXPIRATION_DATE = prism_cover_sheet_row.OBLIGATION_EXPIRATION_DATE,
                  EXPENDITURE_EXPIRATION_DATE = prism_cover_sheet_row.EXPENDITURE_EXPIRATION_DATE,
                  pr_status = prism_cover_sheet_row.pr_status,
                  PR_USER_ID = prism_cover_sheet_row.PR_USER_ID,
                  PR_REQUEST_DATE = prism_cover_sheet_row.PR_REQUEST_DATE,
                  PR_FOUND = prism_cover_sheet_row.PR_FOUND,
                  PR_STATUS_BACK_FLAG =PRISM_COVER_SHEET_ROW.PR_STATUS_bACK_FLAG,
                  contract_num = PRISM_COVER_SHEET_ROW.contract_num
                  --PR_IMAGE_TYPE ='PDF'
          WHERE   pr = prism_cover_sheet_row.pr;
                  
                    -- dbms_output.put_line('after update')
            
      END LOOP;
      
      commit;


   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;
  
   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_pr_status_Track_main
     PURPOSE:     Calling all sub procedures on status track main procedure.

   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

   PROCEDURE p_pr_status_Track_main (p_pr IN VARCHAR2)
   IS
      os_err_msg         VARCHAR2 (3000);

      /*select the pr from kitt pr request table for given pr if the pr status back flag is 'N'
         and pr job status is in 'Draft' */
      CURSOR c1
      IS
         SELECT   *                                         --pr, contract_num
           FROM   KITT_PR_REQUEST
          WHERE       1 = 1
                  AND PR_STATUS_BACK_FLAG = 'N'
                  AND pr_job_status = 'Draft'
                  --and contract_num in (select contract_num from contract_user)
                  AND pr = p_pr;

      v_pr_count         NUMBER;
      i                  VARCHAR2 (4000);
      v_pr_data_source   VARCHAR2 (20);
   BEGIN
      FOR c_Row IN c1
      LOOP
         -- update kitt pr request table with pr job status as 'In Progress' for given pr
         UPDATE   KITT_PR_REQUEST
            SET   pr_job_status = 'In Progress'
          WHERE       1 = 1
                  AND pr = c_row.pr
                  AND PR_STATUS_BACK_FLAG = 'N'
                  AND pr_job_status = 'Draft';

         COMMIT;

              /* If the given pr is exists in prism pr cover sheet table then first
            delete the pr from prism pr cover sheet table before it get refreshed from prism database */
         DELETE FROM   prism_pr_cover_sheet
               WHERE   pr = c_row.pr AND contract_num = c_row.contract_num;

         -- insert pr detail information into prism_pr_cover_sheet after find in prism database.
         p_insert_pr_cover_sheet (c_Row.pr, c_Row.contract_num, os_err_msg);

         -- select count from prims pr cover sheet table for give pr after the pr refresh in prism pr cover sheet table
         SELECT   COUNT ( * )
           INTO   v_pr_count
           FROM   prism_pr_cover_sheet
          WHERE   pr = c_Row.pr;

         IF v_pr_count <> 0
         THEN
          /*  IF v_pr_data_source = 'ReqSrch'
           -- THEN
               --/* if the pr already exists in prims pr cover sheet table before refresh and storing pr data source
                --   as 'ReqSrch' then update the prism pr cover sheet table after the refresh for same pr  as 'PostReqSrch' 
               UPDATE   prism_pr_cover_sheet
                  SET   pr_data_source = 'PostReqSrch'
                WHERE   pr = c_Row.pr;
            ELSE
               --if the pr not exists in prims pr cover sheet table before refresh and it's refreshed first time
               -- then update the pr_data_source as 'Web Service' 
               UPDATE   prism_pr_cover_sheet
                  SET   pr_data_source = 'Web Service'
                WHERE   pr = c_Row.pr;
            END IF;*/

            COMMIT;
            -- call the below procedures to update the KITT value added fields in prism pr cover sheet table
            p_update_expdate (c_Row.pr, os_err_msg);
            P_PR_TOT_AMT (c_Row.pr, os_err_msg);
            P_UPDATE_PR_FOUND_FLAG (c_Row.pr, os_err_msg);
            p_non_released_route_hist (c_Row.pr,
                                       c_Row.contract_num,
                                       os_err_msg);
            p_released_route_hist (c_Row.pr, c_Row.contract_num, os_err_msg);
            COMMIT;

            p_refresh_PRISM_PR_IMAGE (c_Row.pr,
                                      c_Row.contract_num,
                                      os_err_msg);


            /* once the refresh is done in prism pr cover sheet table then update kitt pr request
               with pr status back flag as 'Y' & pr job status as ;Completed' if the pr already found in prism database for give pr  */
            UPDATE   KITT_PR_REQUEST
               SET   PR_STATUS_BACK_FLAG = 'Y', pr_job_status = 'Completed'
             WHERE   pr IN (SELECT   pr
                              FROM   KITT_PR_REQUEST
                             WHERE   pr = c_row.pr AND pr_found = 'Y');

            -- update the prism pr image table with pr status back flag as kitt pr request status flag for the given pr
            UPDATE   prism_pr_image
               SET   PR_STATUS_BACK_FLAG =
                        (SELECT   PR_STATUS_BACK_FLAG
                           FROM   kitt_pr_request
                          WHERE   pr = c_Row.pr)
             WHERE   pr = c_row.pr;

            COMMIT;
         -- PK_COVERSHEET_CALLBACK.SET_COVERSHEET_STATUS(c_Row.contract_num,c_Row.pr,'Y',null);

         ELSE
            -- os_err_msg:='PR '|| c_Row.pr ||' and Contract Num '||c_Row.contract_num ||' is not found in prism database';

            -- PK_COVERSHEET_CALLBACK.SET_COVERSHEET_STATUS(c_Row.contract_num,c_Row.pr,'N','PR is not found in prism system');

            /* if the pr not found in prism database and not inserted in prism pr cover sheet table
               then update kitt pr request table with pr_found as 'N', pr job_status as 'Completed' and pr status back flag as 'Y'
            */
            UPDATE   KITT_PR_REQUEST
               SET   PR_STATUS_BACK_FLAG = 'Y',
                     pr_job_status = 'Completed',
                     pr_found = 'N'
             WHERE   pr IN
                           (SELECT   pr
                              FROM   KITT_PR_REQUEST
                             WHERE   pr = c_row.pr
                                     AND NVL (pr_found, 'N') = 'N');

            COMMIT;
         END IF;


         COMMIT;
      END LOOP;



      COMMIT;
   END p_pr_status_Track_main;

   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_insert_pre_pr_cover_sheet
     PURPOSE:     COllect lis to requisitions for given contract and verify in prism database
                  and populate into pre_prism_pr_cover_sheet table.
   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

   PROCEDURE p_insert_pre_pr_cover_sheet (p_contract_num       VARCHAR2,
                                          os_err_msg       OUT VARCHAR2)
   IS
   begin 
   null;
   END p_insert_pre_pr_cover_sheet;

   /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      NAME:       p_exist_pr_status_refresh_req
     PURPOSE:     Populate PR detail data into prism_pr_cover_sheet table for given contract &
                  requisition if the pr is not exist in kitt_pr_request table.
                  This procedure is going to schedule the dbms job ever 2 hours.
   --XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
   PROCEDURE p_exist_pr_status_refresh_req
   IS
      begin
      null;
   END p_exist_pr_status_refresh_req;
   
   
   PROCEDURE insert_pr_image_pdf ( 
                                    PR_NUM varchar2)  
   IS 
     --PR_NUM varchar2(30):='WA-12-05538';
      x_blob        BLOB;
      fils          BFILE := BFILENAME ('PRISM_PR_IMAGE', PR_NUM||'.pdf');
      blob_length   INTEGER;
   BEGIN
      BEGIN
         -- Obtain the size of the blob file
         DBMS_LOB.fileopen (fils, DBMS_LOB.file_readonly);
         blob_length := DBMS_LOB.getlength (fils);
         DBMS_LOB.fileclose (fils);
         
         -- delete the record from prism_pr_image table before insert
         
            delete from prism_pr_image
            where pr = pr_num;
         -- Insert a new record into the table containing the filename you have specified and a
         -- Return the LOB LOCATOR and assign it to x_blob.
        --dbms_output.put_line('before insert');
         INSERT INTO prism_pr_image (pr, pr_image_pdf_file)
              VALUES (PR_NUM, EMPTY_BLOB ())
               RETURNING pr_image_pdf_file
                INTO x_blob;
          --  dbms_output.put_line('after insert');
         -- Load the file into the database as a BLOB
         DBMS_LOB.OPEN (fils, DBMS_LOB.lob_readonly);
         DBMS_LOB.OPEN (x_blob, DBMS_LOB.lob_readwrite);
         DBMS_LOB.loadfromfile (x_blob, fils, blob_length);
         -- Close handles to blob and file
         DBMS_LOB.CLOSE (x_blob);
         DBMS_LOB.CLOSE (fils);
          COMMIT;
         -- Confirm insert by querying the database for LOB length information and output resul
         blob_length := 0;
         --dbms_output.put_line('before select');
         SELECT DBMS_LOB.getlength (pr_image_pdf_file)
           INTO blob_length
           FROM prism_pr_image
          WHERE pr = PR_NUM;
        -- fnd_file.
        --  put_line (
          --  FND_FILE.LOG,
          --     'Successfully inserted BLOB '''
          -- || ''' of size '
          --  || blob_length
           -- || ' bytes.');
      EXCEPTION
         WHEN OTHERS
         THEN
        null;
      end;
   END ;
      
END prism_pr_status_track; 
/
