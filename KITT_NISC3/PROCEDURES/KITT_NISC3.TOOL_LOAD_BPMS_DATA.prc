DROP PROCEDURE TOOL_LOAD_BPMS_DATA;

CREATE OR REPLACE PROCEDURE            TOOL_LOAD_BPMS_DATA AS
  v_FoundDelphi NUMBER := 0;
  v_NewDelphi NUMBER := 0;
  v_PMOId NUMBER := 0;
  v_Fee NUMBER := 0;
BEGIN
  SELECT MAX(N_USER_PROFILE_ID) INTO v_PMOId
    FROM USER_ROLE UR, SYSTEM_ROLE SR
   WHERE UPPER(SR.C_ROLE_LABEL) = 'PMO'
     AND UPPER(UR.F_PRIMARY_ROLE) = 'Y'
     AND SR.N_ROLE_NUMBER = UR.N_ROLE_NUMBER;
     
  DBMS_OUTPUT.ENABLE;
  FOR c_PR IN
  ( SELECT 
    PR,
    PROJECT_NUMBER,
    LINE_ITEM,
    QUANTITY_ORDERED,
           QUANTITY_BILLED,
    QUANTITY_RECEIVED,
    QUANTITY_CANCELLED,
    TASK_NUMBER,
    CHARGE_ACCOUNT,
    MULTIPLIER,
    FUND,
    LINE_NUM,
    SHIPMENT_NUMBER,
    DISTRIBUTION_NUM,
    TYPE_OF_FUNDS,
    TO_DATE(EXPENDITURE_EXPIRATION_DATE, 'MM/DD/YYYY') AS EXPIRATION_DATE,
    FUND_DESCRIPTION,
    D_EXTRACT_DATE,
    DECODE(CONTRACT_MOD#, 'ORIG', 0, TO_NUMBER(CONTRACT_MOD#)) AS MOD_NUMBER,
    C_DEOBLIGATE,
    C_DELETE,
    C_CORE,
    C_HOLD,
    C_EXEMPT 
      FROM PRISM_PR_DELPHI_PO
    WHERE (PR IS NOT NULL)
    AND TO_DATE(ACTION_TAKEN_DATE) >= TO_DATE(SYSDATE-2) )
  LOOP
    SELECT COUNT(*) INTO v_FoundDelphi
      FROM DELPHI_OBLIGATION
     WHERE C_CHARGE_ACCOUNT = c_PR.CHARGE_ACCOUNT
       AND N_LINE_NUMBER = c_PR.LINE_NUM
       AND N_SHIPMENT_NUMBER = c_PR.SHIPMENT_NUMBER
       AND N_DISTRIBUTION_NUMBER = c_PR.DISTRIBUTION_NUM;

    DBMS_OUTPUT.PUT_LINE('Found L-S-D ' || c_PR.LINE_NUM || '-' || c_PR.SHIPMENT_NUMBER || '-' 
      || c_PR.DISTRIBUTION_NUM || ' = ' || v_FoundDelphi);
    
    IF (v_FoundDelphi > 0) THEN
      update DELPHI_OBLIGATION
     set C_LINE_ITEM = c_PR.LINE_ITEM, 
    QUANTITY_ORDERED = c_PR.QUANTITY_ORDERED, 
    QUANTITY_BILLED = c_PR.QUANTITY_BILLED,
    QUANTITY_RECEIVED = c_PR.QUANTITY_RECEIVED,
    QUANTITY_CANCELLED = c_PR.QUANTITY_CANCELLED, 
    C_DELPHI_ELEMENTS = c_PR.CHARGE_ACCOUNT,
    C_FUNDING_TYPE = c_PR.TYPE_OF_FUNDS,
    N_MULTIPLIER = c_PR.MULTIPLIER, 
    C_FUND = c_PR.FUND,
    C_TYPE_OF_FUNDS = c_PR.TYPE_OF_FUNDS, 
    D_EXPIRATION_DATE = c_PR.EXPIRATION_DATE,
    C_FUND_DESCRIPTION = c_PR.FUND_DESCRIPTION,
    D_EXTRACT_DATE = c_PR.D_EXTRACT_DATE,
    N_MOD_NUMBER = c_PR.MOD_NUMBER,
    C_DEOBLIGATE = c_PR.C_DEOBLIGATE,
    C_DELETE = c_PR.C_DELETE,
    C_CORE = c_PR.C_CORE,
    C_HOLD = c_PR.C_HOLD,
    C_EXEMPT = c_PR.C_EXEMPT,
    C_PR_NUMBER = c_PR.PR    
      where C_CHARGE_ACCOUNT = c_PR.CHARGE_ACCOUNT
        and N_LINE_NUMBER = c_PR.LINE_NUM
        and N_SHIPMENT_NUMBER = c_PR.SHIPMENT_NUMBER
        and N_DISTRIBUTION_NUMBER = c_PR.DISTRIBUTION_NUM;
    ELSE
      SELECT SEQ_DELPHI_OBLIGATION.NEXTVAL INTO v_NewDelphi FROM DUAL;
      
      INSERT INTO DELPHI_OBLIGATION (
        N_DELPHI_OBLIGATION_ID,
        C_PR_PROJECT_NUMBER,
        C_LINE_ITEM,
        C_TASK_NUMBER,
        C_DELPHI_CODE,
        N_SHIPMENT_NUMBER, 
        N_LINE_NUMBER,
        N_DISTRIBUTION_NUMBER,
        QUANTITY_ORDERED,
        QUANTITY_BILLED,
        QUANTITY_RECEIVED,
        QUANTITY_CANCELLED,
        C_DELPHI_ELEMENTS,
        C_FUNDING_TYPE,
        C_CHARGE_ACCOUNT,
        N_MULTIPLIER,
        C_FUND,
        C_TYPE_OF_FUNDS,
        D_EXPIRATION_DATE, 
        C_FUND_DESCRIPTION,
        T_COMMENTS,
        C_PR_NUMBER,
        D_EXTRACT_DATE,
        N_MOD_NUMBER,
        C_DEOBLIGATE,
        C_DELETE,
        C_CORE,
        C_HOLD,
        C_EXEMPT)
      VALUES (
        v_NewDelphi,
        c_PR.PROJECT_NUMBER,
        c_PR.LINE_ITEM,
        c_PR.TASK_NUMBER,
        c_PR.CHARGE_ACCOUNT,
        c_PR.SHIPMENT_NUMBER,
        c_PR.LINE_NUM,
        c_PR.DISTRIBUTION_NUM,
        c_PR.QUANTITY_ORDERED,
        c_PR.QUANTITY_BILLED,
        c_PR.QUANTITY_RECEIVED,
        c_PR.QUANTITY_CANCELLED,
        c_PR.CHARGE_ACCOUNT,
        c_PR.TYPE_OF_FUNDS,
        c_PR.CHARGE_ACCOUNT,
        c_PR.MULTIPLIER,
        c_PR.FUND,
        NVL(c_PR.TYPE_OF_FUNDS, ''),
        NVL(c_PR.EXPIRATION_DATE, ''),
        c_PR.FUND_DESCRIPTION,
        'Loaded through TOOL_LOAD_BPMS',
        c_PR.PR,
        c_PR.D_EXTRACT_DATE,
        c_PR.MOD_NUMBER,
        c_PR.C_DEOBLIGATE,
        c_PR.C_DELETE,
        c_PR.C_CORE,
        c_PR.C_HOLD,
        c_PR.C_EXEMPT );
        
      IF (UPPER(c_PR.C_EXEMPT) = 'Y') THEN
        INSERT INTO FEE (
          N_FEE_ID, 
          C_PR_NUMBER, 
          N_DELPHI_OBLIGATION_ID,
          N_PMO_ID,
          N_FEE_AMOUNT,
          T_COMMENT,
          D_FEE_ALLOCATION_TS )
        VALUES (
          SEQ_FEE.NEXTVAL,
          c_PR.PR,
          v_NewDelphi,
          v_PMOId,
          0.00,
          'This record is exempt from fee.  Fee amount is $0.00.  It was loaded via TOOL_LOAD_BPMS',
          SYSDATE );
      ELSE
        v_Fee := ROUND(((c_PR.QUANTITY_ORDERED - c_PR.QUANTITY_CANCELLED) / 1.115) * 0.115, 2);
        INSERT INTO FEE (
          N_FEE_ID, 
          C_PR_NUMBER, 
          N_DELPHI_OBLIGATION_ID,
          N_PMO_ID,
          N_FEE_AMOUNT,
          T_COMMENT,
          D_FEE_ALLOCATION_TS )
        VALUES (
          SEQ_FEE.NEXTVAL,
          c_PR.PR,
          v_NewDelphi,
          v_PMOId,
          v_Fee,
          'Fee was calculated by ' || c_PR.QUANTITY_ORDERED || ' - ' || c_PR.QUANTITY_CANCELLED || 
          '/1.115*0.115 = $' || v_Fee || '.   It was loaded via TOOL_LOAD_BPMS',
          SYSDATE );
      END IF;      
    END IF;
  END LOOP;
  
  INSERT INTO SCHEDULED_TASK_LOG ( N_SCHEDULE_TASK_LOG_ID, C_ACTION_LABEL, D_TASK_DATE, C_DESCRIPTION )
    VALUES ( SEQ_SCHEDULED_TASK_LOG.NEXTVAL, 'TOOL_LOAD_BPMS', SYSDATE, 'Load BPMS Data run via PL/SQL completed.');
END TOOL_LOAD_BPMS_DATA;
/
