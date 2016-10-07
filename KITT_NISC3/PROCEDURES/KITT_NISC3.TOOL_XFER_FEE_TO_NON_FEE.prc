DROP PROCEDURE TOOL_XFER_FEE_TO_NON_FEE;

CREATE OR REPLACE PROCEDURE TOOL_XFER_FEE_TO_NON_FEE
( DelphiObligation IN NUMBER
, Amount IN NUMBER
, UserId IN NUMBER )
AS
  UserName VARCHAR2(100);
  LogMsg VARCHAR2(1000);
  AuditMsg VARCHAR2(2000);
BEGIN
  SELECT C_USER_NAME INTO UserName
    FROM USER_PROFILE
   WHERE N_USER_PROFILE_ID = UserId;

  UPDATE FEE
     SET N_FEE_AMOUNT = N_FEE_AMOUNT - Amount
       , T_COMMENT = T_COMMENT || '  - $' || Amount || ' for Fee->Non-Fee Transfer by ' || UserName
   WHERE N_DELPHI_OBLIGATION_ID = DelphiObligation;

  LogMsg := '$' || Amount || ' was transfered from FEE to NON-FEE by user ' || UserName || ' on Obligation#' || DelphiObligation;
  DBMS_OUTPUT.PUT_LINE( LogMsg );

  INSERT INTO KITT_LOG ( N_LOG_ID, N_CONTRACT_ID, F_LOG_CATEGORY, C_MESSAGE, D_REC_VERSION )
  SELECT SEQ_KITT_LOG.NEXTVAL, N_CONTRACT_ID, 'INFO', LogMsg, SYSDATE
    FROM CONTRACT;

  -- <TRANSACTION><User_Id>USER</User_Id><Object_Type>Obligation</Object_Type>
  --   <Object_Id>###</Object_Id><Amount>###.##</Amount></TRANSACTION>
  AuditMsg := '<TRANSACTION><User_Id>'|| UserName ||'</User_Id><Action>TransferFeeToNonFee</Action><Object_Type>Obligation</Object_Type>' ||
                  '<Object_Id>' || DelphiObligation || '</Object_Id><Amount>' || Amount || '</Amount></TRANSACTION>';
  INSERT INTO KITT_AUDIT VALUES
      ( UserId, SYSDATE, 'Fee Transfer to Non-Fee', XMLType(AuditMsg) );
END TOOL_XFER_FEE_TO_NON_FEE;
/
