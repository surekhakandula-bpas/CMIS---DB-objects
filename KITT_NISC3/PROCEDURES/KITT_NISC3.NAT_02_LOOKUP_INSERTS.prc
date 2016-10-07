DROP PROCEDURE NAT_02_LOOKUP_INSERTS;

CREATE OR REPLACE PROCEDURE            "NAT_02_LOOKUP_INSERTS"
AS
BEGIN
   --SET DEFINE OFF;

   /*
   Step 1 of 8:
   Insert into table CONTRACTOR_MAP any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO CONTRACTOR_MAP (C_CM_CTR_NAME,
                               N_CM_NAT_ID,
                               N_CM_KITT2_ID,
                               N_CONTRACTOR_MAP_ID)
      SELECT CONTRACTOR_MAP_ROWS.C_CM_CTR_NAME,
             CONTRACTOR_MAP_ROWS.N_CM_NAT_ID,
             ROWNUM + (SELECT MAX (N_CONTRACTOR_ID) FROM CONTRACTOR)
                N_CM_KITT2_ID,
             ROWNUM + (SELECT MAX (N_CONTRACTOR_MAP_ID) FROM CONTRACTOR_MAP)
                N_CONTRACTOR_MAP_ID
        FROM (  SELECT *
                  FROM (SELECT COMPANY_NAME C_CM_CTR_NAME,
                               COMPANY_ID N_CM_NAT_ID
                          FROM NAT_INVOICE_LINE_ITEM
                         WHERE LOWER (COMPANY_NAME) NOT IN (SELECT DISTINCT
                                                                   LOWER (
                                                                      C_NAME)
                                                              FROM CONTRACTOR))
              GROUP BY C_CM_CTR_NAME, N_CM_NAT_ID
              ORDER BY C_CM_CTR_NAME) CONTRACTOR_MAP_ROWS
       /*
       do not create duplicate entries:
       */
       WHERE N_CM_NAT_ID NOT IN (SELECT N_CM_NAT_ID FROM CONTRACTOR_MAP);

   COMMIT;

   /*
   Step 2 of 8:
   Insert into table CONTRACTOR any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO CONTRACTOR (C_CONTRACTOR_LABEL,
                           T_COMMENTS,
                           C_NAME,
                           C_CONTRACT_TYPE,
                           C_BILLING_TYPE,
                           N_CONTRACTOR_ID)
      SELECT C_CONTRACTOR_LABEL,
             T_COMMENTS,
             C_NAME,
             C_CONTRACT_TYPE,
             C_BILLING_TYPE,
             N_CONTRACTOR_ID
        FROM (SELECT CONTRACTOR_ROWS.*,
                     ROWNUM + (SELECT MAX (N_CONTRACTOR_ID) FROM CONTRACTOR)
                        N_CONTRACTOR_ID
                FROM (  SELECT *
                          FROM (SELECT COMPANY_NAME C_CONTRACTOR_LABEL,
                                       COMPANY_NAME T_COMMENTS,
                                       COMPANY_NAME C_NAME,
                                       'LMC' C_CONTRACT_TYPE,
                                       'COSTPLUS' C_BILLING_TYPE
                                  FROM NAT_INVOICE_LINE_ITEM
                                 WHERE LOWER (COMPANY_NAME) NOT IN (SELECT DISTINCT
                                                                           LOWER (
                                                                              C_NAME)
                                                                      FROM CONTRACTOR))
                      GROUP BY C_CONTRACTOR_LABEL,
                               T_COMMENTS,
                               C_NAME,
                               C_CONTRACT_TYPE,
                               C_BILLING_TYPE
                      ORDER BY C_CONTRACTOR_LABEL) CONTRACTOR_ROWS)
       /*
       do not create unused entries:
       */
       WHERE N_CONTRACTOR_ID IN (SELECT N_CM_KITT2_ID
                                   FROM CONTRACTOR_MAP
                                  WHERE N_CM_KITT2_ID NOT IN (SELECT N_CONTRACTOR_ID
                                                                FROM CONTRACTOR));

   COMMIT;

   /*
   Step 3 of 8:
   Insert into table COST_TYPE_MAP any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO COST_TYPE_MAP (C_CTM_COST_TYPE_LABEL,
                              N_CTM_NAT_ID,
                              N_CTM_KITT2_ID,
                              N_COST_TYPE_MAP_ID,
                              N_CTM_NAT_LABOR_TYPE)
      SELECT COST_TYPE_MAP_ROWS.C_CTM_COST_TYPE_LABEL,
             COST_TYPE_MAP_ROWS.N_CTM_NAT_ID,
             COST_TYPE_MAP_ROWS.N_CTM_NAT_LABOR_TYPE,
             ROWNUM + (SELECT MAX (N_COST_TYPE_ID) FROM COST_TYPE)
                N_CTM_KITT2_ID,
             ROWNUM + (SELECT MAX (N_COST_TYPE_MAP_ID) FROM COST_TYPE_MAP)
                N_COST_TYPE_MAP_ID
        FROM (  SELECT *
                  FROM (SELECT COSTTYPE_LABEL C_CTM_COST_TYPE_LABEL,
                               COSTTYPE_ID N_CTM_NAT_ID,
                               SUBCOSTTYPE_ID N_CTM_NAT_LABOR_TYPE
                          FROM NAT_INVOICE_LINE_ITEM
                         WHERE LOWER (COSTTYPE_LABEL) NOT IN (SELECT DISTINCT
                                                                     LOWER (
                                                                        C_COST_TYPE_LABEL)
                                                                FROM COST_TYPE))
              GROUP BY C_CTM_COST_TYPE_LABEL,
                       N_CTM_NAT_ID,
                       N_CTM_NAT_LABOR_TYPE
              ORDER BY C_CTM_COST_TYPE_LABEL) COST_TYPE_MAP_ROWS
       /*
       do not create duplicate entries:
       */
       WHERE N_CTM_NAT_ID NOT IN (SELECT N_CTM_NAT_ID FROM COST_TYPE_MAP);

   COMMIT;

   /*
   Step 4 of 8:
   Insert into table COST_TYPE any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO COST_TYPE (C_COST_TYPE_LABEL, T_COMMENTS, N_COST_TYPE_ID)
      SELECT C_COST_TYPE_LABEL, T_COMMENTS, N_COST_TYPE_ID
        FROM (SELECT COST_TYPE_ROWS.*,
                     ROWNUM + (SELECT MAX (N_COST_TYPE_ID) FROM COST_TYPE)
                        N_COST_TYPE_ID
                FROM (  SELECT *
                          FROM (SELECT COSTTYPE_LABEL C_COST_TYPE_LABEL,
                                       COSTTYPE_LABEL T_COMMENTS
                                  FROM NAT_INVOICE_LINE_ITEM
                                 WHERE LOWER (COSTTYPE_LABEL) NOT IN (SELECT DISTINCT
                                                                             LOWER (
                                                                                C_COST_TYPE_LABEL)
                                                                        FROM COST_TYPE))
                      GROUP BY C_COST_TYPE_LABEL, T_COMMENTS
                      ORDER BY C_COST_TYPE_LABEL) COST_TYPE_ROWS)
       /*
       do not create unused entries:
       */
       WHERE N_COST_TYPE_ID IN (SELECT N_CTM_KITT2_ID
                                  FROM COST_TYPE_MAP
                                 WHERE N_CTM_KITT2_ID NOT IN (SELECT N_COST_TYPE_ID
                                                                FROM COST_TYPE));

   COMMIT;

   /*
   Step 5 of 8:
   Insert into table LABOR_CATEGORY_MAP any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO LABOR_CATEGORY_MAP (C_LCM_LABOR_CATEGORY_LABEL,
                                   N_LCM_NAT_ID,
                                   N_LCM_KITT2_ID,
                                   N_LABOR_CATEGORY_MAP_ID)
      SELECT LABOR_CATEGORY_MAP_ROWS.C_LCM_LABOR_CATEGORY_LABEL,
             LABOR_CATEGORY_MAP_ROWS.N_LCM_NAT_ID,
             ROWNUM + (SELECT MAX (N_LABOR_CATEGORY_ID) FROM LABOR_CATEGORY)
                N_LCM_KITT2_ID,
               ROWNUM
             + (SELECT MAX (N_LABOR_CATEGORY_MAP_ID) FROM LABOR_CATEGORY_MAP)
                N_LABOR_CATEGORY_MAP_ID
        FROM (  SELECT *
                  FROM (SELECT LABORCATEGORY_NAME C_LCM_LABOR_CATEGORY_LABEL,
                               LABORCATEGORY_ID N_LCM_NAT_ID
                          FROM NAT_INVOICE_LINE_ITEM
                         WHERE LOWER (LABORCATEGORY_NAME) NOT IN (SELECT DISTINCT
                                                                         LOWER (
                                                                            C_LABOR_CATEGORY_LABEL)
                                                                    FROM LABOR_CATEGORY))
              GROUP BY C_LCM_LABOR_CATEGORY_LABEL, N_LCM_NAT_ID
              ORDER BY C_LCM_LABOR_CATEGORY_LABEL) LABOR_CATEGORY_MAP_ROWS
       /*
       do not create duplicate entries:
       */
       WHERE N_LCM_NAT_ID NOT IN (SELECT N_LCM_NAT_ID FROM LABOR_CATEGORY_MAP);

   COMMIT;

   /*
   Step 6 of 8:
   Insert into table LABOR_CATEGORY any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO LABOR_CATEGORY (C_LABOR_CATEGORY_LABEL,
                               ACTIVE_STATUS,
                               N_LABOR_CATEGORY_ID)
      SELECT C_LABOR_CATEGORY_LABEL, ACTIVE_STATUS, N_LABOR_CATEGORY_ID
        FROM (SELECT LABOR_CATEGORY_ROWS.*,
                       ROWNUM
                     + (SELECT MAX (N_LABOR_CATEGORY_ID) FROM LABOR_CATEGORY)
                        N_LABOR_CATEGORY_ID
                FROM (  SELECT *
                          FROM (SELECT LABORCATEGORY_NAME
                                          C_LABOR_CATEGORY_LABEL,
                                       'A' ACTIVE_STATUS
                                  FROM NAT_INVOICE_LINE_ITEM
                                 WHERE LOWER (LABORCATEGORY_NAME) NOT IN (SELECT DISTINCT
                                                                                 LOWER (
                                                                                    C_LABOR_CATEGORY_LABEL)
                                                                            FROM LABOR_CATEGORY))
                      GROUP BY C_LABOR_CATEGORY_LABEL, ACTIVE_STATUS
                      ORDER BY C_LABOR_CATEGORY_LABEL) LABOR_CATEGORY_ROWS)
       /*
       do not create unused entries:
       */
       WHERE N_LABOR_CATEGORY_ID IN (SELECT N_LCM_KITT2_ID
                                       FROM LABOR_CATEGORY_MAP
                                      WHERE N_LCM_KITT2_ID NOT IN (SELECT N_LABOR_CATEGORY_ID
                                                                     FROM LABOR_CATEGORY));

   COMMIT;

   /*
   Step 7 of 8:
   Insert into table ODC_TYPE_MAP any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO ODC_TYPE_MAP (C_OTM_ODC_TYPE_LABEL,
                             N_OTM_NAT_ID,
                             N_OTM_KITT2_ID,
                             N_ODC_TYPE_MAP_ID)
      SELECT ODC_TYPE_MAP_ROWS.C_OTM_ODC_TYPE_LABEL,
             ODC_TYPE_MAP_ROWS.N_OTM_NAT_ID,
             ROWNUM + (SELECT MAX (N_ODC_TYPE_ID) FROM ODC_TYPE)
                N_OTM_KITT2_ID,
             ROWNUM + (SELECT MAX (N_ODC_TYPE_MAP_ID) FROM ODC_TYPE_MAP)
                N_ODC_TYPE_MAP_ID
        FROM (  SELECT *
                  FROM (SELECT SUBCOSTTYPE_LABEL C_OTM_ODC_TYPE_LABEL,
                               SUBCOSTTYPE_ID N_OTM_NAT_ID
                          FROM NAT_INVOICE_LINE_ITEM
                         WHERE LOWER (SUBCOSTTYPE_LABEL) NOT IN (SELECT DISTINCT
                                                                        LOWER (
                                                                           C_ODC_TYPE_LABEL)
                                                                   FROM ODC_TYPE))
              GROUP BY C_OTM_ODC_TYPE_LABEL, N_OTM_NAT_ID
              ORDER BY C_OTM_ODC_TYPE_LABEL) ODC_TYPE_MAP_ROWS
       /*
       do not create duplicate entries:
       */
       WHERE N_OTM_NAT_ID NOT IN (SELECT N_OTM_NAT_ID FROM COST_TYPE_MAP);

   COMMIT;

   /*
   Step 8 of 8:
   Insert into table ODC_TYPE any new contractors found in NAT_INVOICE_LINE_ITEM.
   */
   INSERT INTO ODC_TYPE (C_ODC_TYPE_LABEL, N_ODC_TYPE_ID)
      SELECT C_ODC_TYPE_LABEL, N_ODC_TYPE_ID
        FROM (SELECT ODC_TYPE_ROWS.C_ODC_TYPE_LABEL,
                     ROWNUM + (SELECT MAX (N_ODC_TYPE_ID) FROM ODC_TYPE)
                        N_ODC_TYPE_ID
                FROM (  SELECT *
                          FROM (SELECT SUBCOSTTYPE_LABEL C_ODC_TYPE_LABEL
                                  FROM NAT_INVOICE_LINE_ITEM
                                 WHERE LOWER (SUBCOSTTYPE_LABEL) NOT IN (SELECT DISTINCT
                                                                                LOWER (
                                                                                   C_ODC_TYPE_LABEL)
                                                                           FROM ODC_TYPE))
                      GROUP BY C_ODC_TYPE_LABEL
                      ORDER BY C_ODC_TYPE_LABEL) ODC_TYPE_ROWS)
       /*
       do not create unused entries:
       */
       WHERE N_ODC_TYPE_ID IN (SELECT N_OTM_KITT2_ID
                                 FROM ODC_TYPE_MAP
                                WHERE N_OTM_KITT2_ID NOT IN (SELECT N_ODC_TYPE_ID
                                                               FROM ODC_TYPE));

   COMMIT;
END NAT_02_LOOKUP_INSERTS;
/
