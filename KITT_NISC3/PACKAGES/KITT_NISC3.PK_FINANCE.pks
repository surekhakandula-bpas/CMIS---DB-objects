DROP PACKAGE PK_FINANCE;

CREATE OR REPLACE PACKAGE            PK_FINANCE AS
/******************************************************************************
   NAME:       PK_FINANCE
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/3/2010             1. Created this package.
******************************************************************************/
PROCEDURE FIN_TASK_FUND_CHANGE_ETO ( MY_TASK_ORDER_BASE_ID IN NUMBER,
                                     MY_OLD_ETO_ID    IN NUMBER,
                                     MY_NEW_ETO_ID    IN NUMBER,
                                     MY_LOGINUSER_ID  IN NUMBER,
                                     MY_STATUS       OUT VARCHAR2,
                                     MY_MSG          OUT VARCHAR2);


PROCEDURE FIN_XFER_UNALLOCATED_FUNDS (
                                      MY_OLD_ETO_ID    IN NUMBER,
                                      MY_NEW_ETO_ID    IN NUMBER,
                                      MY_USER_ID       IN NUMBER,
                                      MY_STATUS       OUT VARCHAR2,
                                      MY_MSG          OUT VARCHAR2);

PROCEDURE CHANGE_ETO (   new_eto_id number,
                         old_eto_id number,
                         user_id number);

END PK_FINANCE;
/

DROP PACKAGE BODY PK_FINANCE;

CREATE OR REPLACE PACKAGE BODY            PK_FINANCE AS
/******************************************************************************
   NAME:       PK_FINANCE
   PURPOSE:    This package provide procedures to handle financial related functions
               1) Change ETO
               2) Loading awarefee

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/3/2010             1. Created this package body.
******************************************************************************/

PROCEDURE  SEND_SUPPORT_EMAIL (MySupportType varchar2, MyMsg varchar2)

IS

/******************************************************************************
   NAME:       SEND_SUPPORT_EMAIL
   PURPOSE:   Send an email notification to tech support if some actions failed

   REVISIONS:
   Ver        Date        DEVELOPER           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0      04/18/2011  Chao Yu        1. Created this procedure.

******************************************************************************/

   crlf               VARCHAR2(2)    := CHR (13) || CHR (10);
   Sender         VARCHAR2(500)  := 'chao.ctr.yu@faa.gov';
   Receiver       VARCHAR2(500)  := 'chao.ctr.yu@faa.gov';
   Subject         VARCHAR2(500)  := ' ';
   Message       VARCHAR2(2000) := ' ';
   MyRole         VARCHAR2(100);
   CurrDB         VARCHAR2(20);


BEGIN

         MyRole:='Tech Support';

         if   MySupportType = 'CHANGE ETO' then
               Subject:='Change ETO failed in NISCIII';
               Message:= 'Change ETO failed in NISCIII! Please check on it.' ||MyMsg;
         else
               Subject:='Error in NISCIII';
               Message:= 'Error for contract: NISCIII,  Please check on it.' ||MyMsg;
         end if;


    CurrDB := GET_ENV_NAME ;

    Subject:=Subject||' ('||CurrDB||')';

     If CurrDB = 'NISC3_PROD' or CurrDB = 'NISC3_DEV' then

           for p in ( select distinct lower(trim(C_EMAIL_DEVELOPER )) as C_EMAIL_ADDRESS
                        from EMAIL_RECIPIENTS
                        where C_EMAIL_DEVELOPER is not null) loop

                   Receiver:=trim(p.C_EMAIL_ADDRESS );
                   send_email (Sender, Receiver, Subject, Message, MyRole);

           end loop;

    end if;

      Receiver:='chao.ctr.yu@faa.gov';
      send_email (Sender, Receiver, Subject, Message, MyRole);


EXCEPTION
   WHEN OTHERS then
    null;
END;

 PROCEDURE                  FIN_AUDIT ( EVENT       VARCHAR2,
                                        OBJECT_ID   NUMBER,
                                        USER_ID     NUMBER,
                                        DELPHI_ID   NUMBER,
                                        SUBTO_ID    NUMBER,
                                        TO_BASE_ID  NUMBER,
                                        SUBTO_NAME  varchar,
                                        ALLO_AMOUNT NUMBER,
                                        DE_ALLO_AMOUNT NUMBER,
                                        PR_NUMBER   VARCHAR2,
                                        FEE_FLAG    VARCHAR2,
                                        TRANSFER_AMOUNT NUMBER,
                                        TRANSFER_FROM NUMBER,
                                        TRANSFER_TO NUMBER)


IS

/******************************************************************************
   NAME:       FIN_AUDIT
   PURPOSE:

   REVISIONS:
   Ver        Date        Developer           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/12/2010  Chao  Yu      1. Created this procedure.
   1.2        4/13/2011  Chao Yu       2 Add  dbms_output line and remove status and msg parameters

   NOTES:

  This procedure will track the allocation, de-allocation and transfer actions and
  add the action into KITT_AUDIT table

******************************************************************************/

MyAuditXML CLOB;

BEGIN


   If UPPER(EVENT) = 'ALLOCATE' then
         MyAuditXML := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                          <TRANSACTION>
                             <Deallocation_Amount>'||DE_ALLO_AMOUNT||'</Deallocation_Amount>
                             <User_Id>'||USER_ID||'</User_Id>
                             <Event>'||EVENT||'</Event>
                             <Object_Type>Allocation</Object_Type>
                             <Delphi_Id>'||DELPHI_ID||'</Delphi_Id>
                             <Sub_Task_Order_Id>'||SUBTO_ID||'</Sub_Task_Order_Id>
                             <Task_Order_Base_Id>'||TO_BASE_ID||'</Task_Order_Base_Id>
                             <Sub_Task_Order_Name>'||SUBTO_NAME||'</Sub_Task_Order_Name>
                             <Allocation_Amount>'||ALLO_AMOUNT||'</Allocation_Amount>
                             <Object_Id>'||OBJECT_ID||'</Object_Id>
                          </TRANSACTION>';

  elsif UPPER(EVENT) = 'DEALLOCATE' then
          MyAuditXML := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                           <TRANSACTION>
                             <Deallocation_Amount>'||DE_ALLO_AMOUNT||'</Deallocation_Amount>
                             <User_Id>'||USER_ID||'</User_Id>
                             <Event>'||EVENT||'</Event>
                             <Object_Type>Allocation</Object_Type>
                             <Delphi_Id>'||DELPHI_ID||'</Delphi_Id>
                             <Sub_Task_Order_Id>'||SUBTO_ID||'</Sub_Task_Order_Id>
                             <Task_Order_Base_Id>'||TO_BASE_ID||'</Task_Order_Base_Id>
                             <Sub_Task_Order_Name>'||SUBTO_NAME||'</Sub_Task_Order_Name>
                             <Allocation_Amount>'||ALLO_AMOUNT||'</Allocation_Amount>
                             <Object_Id>'||OBJECT_ID||'</Object_Id>
                           </TRANSACTION>';
  elsif  UPPER(EVENT) = 'TRANSFER' then
          MyAuditXML := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                           <TRANSACTION>
                              <Object_Id>'||OBJECT_ID||'</Object_Id>
                              <Pr_Number>'||PR_NUMBER||'</Pr_Number>
                              <F_FEE>'||FEE_FLAG||'</F_FEE>
                              <Object_Type>Transfer</Object_Type>
                              <Delphi_Id>'||DELPHI_ID||'</Delphi_Id>
                              <Transfer_Amount>'||TRANSFER_AMOUNT||'</Transfer_Amount>
                              <User_Id>'||USER_ID||'</User_Id>
                              <Transfer_From_Id>'||TRANSFER_FROM||'</Transfer_From_Id>
                              <Event>'||EVENT||'</Event>
                              <Transfer_To_Id>'||TRANSFER_TO||'</Transfer_To_Id>
                           </TRANSACTION>';

  end if;


INSERT INTO KITT_AUDIT(N_USER_PROFILE_ID,D_REC_VERSION,C_MODULE_NAME,C_TRANSACTION)
       VALUES  (USER_ID,sysdate,'Financial',XMLTYPE(MyAuditXML));

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
      RAISE;
END FIN_AUDIT;

PROCEDURE          ETO_CHANGE_LOG (ACTION_TYPE  VARCHAR2,
                                   SUB_TASK_ORDER_ID NUMBER,
                                   DELPHI_OBLIGATION_ID NUMBER,
                                   FUNDING_AMOUNT NUMBER,
                                   OLD_ETO_ID NUMBER,
                                   NEW_ETO_ID NUMBER,
                                   USER_ID NUMBER)

IS
ID NUMBER;
/******************************************************************************
   NAME:       ETO_CHANGE_LOG
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        08/03/2010   Chao Yu      1. Created this procedure.

   NOTES: This procedure is used to tracking the funding flow during ETO chaging


******************************************************************************/
BEGIN


             insert into UTI_ETO_CHANGE_LOG
                    ( N_ID,
                      C_ACTION,
                      N_SUB_TASK_ORDER_ID,
                      N_DELPHI_OBLIGATION_ID,
                      N_FUNDING_AMOUNT,
                      N_OLD_ETO_ID,
                      N_NEW_ETO_ID,
                      N_USER_ID,
                      D_CHANGE_DATE )
               values (
                       SEQ_UTI_ETO_CHANGE_LOG.nextval,
                       ACTION_TYPE,
                       SUB_TASK_ORDER_ID,
                       DELPHI_OBLIGATION_ID,
                       FUNDING_AMOUNT,
                       OLD_ETO_ID,
                       NEW_ETO_ID,
                       USER_ID,
                       sysdate);

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
        RAISE;

END ETO_CHANGE_LOG;

PROCEDURE FIN_TASK_FUND_CHANGE_ETO ( MY_TASK_ORDER_BASE_ID IN NUMBER,
                                     MY_OLD_ETO_ID    IN NUMBER,
                                     MY_NEW_ETO_ID    IN NUMBER,
                                     MY_LOGINUSER_ID  IN NUMBER,
                                     MY_STATUS       OUT VARCHAR2,
                                     MY_MSG          OUT VARCHAR2)


 IS

/******************************************************************************
   NAME:       FIN_TASK_FUND_CHANGE_ETO
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        08/04/2010     Chao Yu     1. Created this procedure.
   1.1        4/13/2011  Chao Yu         2 . Add message in exception and pass and returen status from ETO_CHANGE_LOG procedure

   NOTES:

   This procedure will handle funding transter from old ETO to new ETO
   changing the task order ETO.
******************************************************************************/

ctn number;
my_pr_number varchar2(25);
allocationID number;
transferID number;


BEGIN

   MY_STATUS :='OK';
   MY_MSG :='SUCCESSFUL';

     -- Verify the OLD_ETO_ID
     select count(*) into ctn
       from USER_PROFILE a, USER_ROLE b, SYSTEM_ROLE c
      where a.N_USER_PROFILE_ID =b.N_USER_PROFILE_ID
        and b.N_ROLE_NUMBER =c.N_ROLE_NUMBER
        and c.C_ROLE_LABEL ='ETO'
        and a.N_USER_PROFILE_ID =MY_OLD_ETO_ID;

      if ctn > 0 then

          -- Verify the NEW_ETO_ID
          select count(*) into ctn
            from USER_PROFILE a, USER_ROLE b, SYSTEM_ROLE c
           where a.N_USER_PROFILE_ID =b.N_USER_PROFILE_ID
             and b.N_ROLE_NUMBER =c.N_ROLE_NUMBER
             and c.C_ROLE_LABEL ='ETO'
             and a.N_USER_PROFILE_ID =MY_NEW_ETO_ID;


           if ctn > 0 then




                  for x in ( select a.N_TASK_ORDER_BASE_ID, a.C_SUB_TASK_ORDER_NAME,a.N_SUB_TASK_ORDER_ID, a.N_DELPHI_OBLIGATION_ID, a.F_FEE, a.N_ETO_ID,a.ALLOCATED_FUND
                               from V_FIN_ALLO_FUND_FOR_SUBTO_ETO a
                              where a.N_TASK_ORDER_BASE_ID = MY_TASK_ORDER_BASE_ID
                                AND a.ALLOCATED_FUND <> 0
                                AND a.N_ETO_ID <> MY_NEW_ETO_ID ) loop


                      -- de-allocation allocated fund ( allocated fund - de-allocated fund + credit) from sub task order
                      Select SEQ_ALLOCATION.nextval into allocationID from dual;

                      BEGIN

                       Insert into  ALLOCATION
                                  ( N_ALLOCATION_ID,
                                    N_SUB_TASK_ORDER_ID,
                                    N_TASK_ORDER_BASE_ID,
                                    C_SUB_TASK_ORDER_NAME,
                                    N_USER_PROFILE_ID,
                                    N_DELPHI_OBLIGATION_ID,
                                    N_ETO_ID,
                                    N_ALLOCATION_AMOUNT,
                                    N_DEALLOCATION_AMOUNT,
                                    D_ALLOCATION_DATE,
                                    F_FEE)
                              values
                                   (allocationID,
                                    x.N_SUB_TASK_ORDER_ID,
                                    x.N_TASK_ORDER_BASE_ID,
                                    x.C_SUB_TASK_ORDER_NAME,
                                    MY_LOGINUSER_ID,
                                    x.N_DELPHI_OBLIGATION_ID,
                                    x.N_ETO_ID,
                                    0,
                                    x.ALLOCATED_FUND,
                                    sysdate,
                                    x.F_FEE);

                      EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                            NULL;
                           WHEN OTHERS THEN
                             MY_STATUS :='FAILED';
                             MY_MSG :='De-allocated fund amount '||x.ALLOCATED_FUND||' from SUBTO '||x.N_SUB_TASK_ORDER_ID||' for line '||x.N_DELPHI_OBLIGATION_ID||' with the ETO '||x.N_ETO_ID||' in Allication table. '||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                             dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                           RAISE;

                      END;

                     BEGIN

                      ETO_CHANGE_LOG ('DE-ALLOCATION',
                                            x.N_SUB_TASK_ORDER_ID,
                                            x.N_DELPHI_OBLIGATION_ID,
                                            x.ALLOCATED_FUND,
                                            x.N_ETO_ID,
                                            null,
                                            MY_LOGINUSER_ID);

                     EXCEPTION

                             WHEN OTHERS THEN
                                    MY_STATUS :='FAILED';
                                    MY_MSG :='Insert a log record into change eto log table for DE-ALLOCATION. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                   dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                   RAISE;
                     END;


                      dbms_output.put_line('De-allocated fund amount '||x.ALLOCATED_FUND||' from SUBTO '||x.N_SUB_TASK_ORDER_ID||' for line '||x.N_DELPHI_OBLIGATION_ID||' with the ETO '||x.N_ETO_ID||'.');


                      BEGIN

                         FIN_AUDIT ( 'deallocate',
                                   allocationID,
                                   MY_LOGINUSER_ID,
                                   x.N_DELPHI_OBLIGATION_ID,
                                   x.N_SUB_TASK_ORDER_ID,
                                   x.N_TASK_ORDER_BASE_ID,
                                   x.C_SUB_TASK_ORDER_NAME,
                                   0,
                                   x.ALLOCATED_FUND,
                                   null,
                                   x.F_FEE,
                                   null,
                                   null,
                                   null);

                      EXCEPTION

                               WHEN OTHERS THEN
                                      MY_STATUS :='FAILED';
                                      MY_MSG :='Insert an audit record into KITT_AUDIT table for deallocate event. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                      dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                       RAISE;
                      END;


                       select C_PR_NUMBER into my_pr_number
                         from DELPHI_OBLIGATION
                        where N_DELPHI_OBLIGATION_ID = x.N_DELPHI_OBLIGATION_ID;

                       --transfer fund from the ETO who de-allocated funding to new ETO

                      select SEQ_TRANSFER.nextval into transferID from dual;

                      BEGIN

                       Insert into TRANSFER
                                 ( N_TRANSFER_ID,
                                   C_PR_NUMBER,
                                   N_DELPHI_OBLIGATION_ID,
                                   N_TRANSFER_AMOUNT,
                                   N_TRANSFER_FROM_ID,
                                   N_TRANSFER_TO_ID,
                                   N_USER_PROFILE_ID,
                                   D_TRANSFER_DATE,
                                   F_FEE )
                               Values
                                 (transferID,
                                  my_pr_number,
                                  x.N_DELPHI_OBLIGATION_ID,
                                  x.ALLOCATED_FUND,
                                  x.N_ETO_ID,
                                  MY_NEW_ETO_ID,
                                  MY_LOGINUSER_ID,
                                  sysdate,
                                  x.F_FEE);

                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                            NULL;
                           WHEN OTHERS THEN
                                MY_STATUS :='FAILED';
                                MY_MSG :='Transfer fund amount '||x.ALLOCATED_FUND||' for line '||x.N_DELPHI_OBLIGATION_ID||' from the ETO '||x.N_ETO_ID||' to NEW ETO '||MY_NEW_ETO_ID||'. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                               dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                               RAISE;

                      END;

                     dbms_output.put_line('Transfer fund amount '||x.ALLOCATED_FUND||' for line '||x.N_DELPHI_OBLIGATION_ID||' from the ETO '||x.N_ETO_ID||' to NEW ETO '||MY_NEW_ETO_ID||'.');

                    BEGIN

                     ETO_CHANGE_LOG ('TRANSFER',
                                            x.N_SUB_TASK_ORDER_ID,
                                            x.N_DELPHI_OBLIGATION_ID,
                                            x.ALLOCATED_FUND,
                                            x.N_ETO_ID,
                                            MY_NEW_ETO_ID,
                                            MY_LOGINUSER_ID);

                    EXCEPTION

                             WHEN OTHERS THEN
                                    MY_STATUS :='FAILED';
                                    MY_MSG :='Insert a log record into change eto log table for TRANSFER. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                   dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                   RAISE;
                     END;

                  BEGIN

                      FIN_AUDIT ( 'transfer',
                                  transferID,
                                  MY_LOGINUSER_ID,
                                  x.N_DELPHI_OBLIGATION_ID,
                                  null,
                                  null,
                                  null,
                                  null,
                                  null,
                                  my_pr_number,
                                  x.F_FEE,
                                  x.ALLOCATED_FUND,
                                  x.N_ETO_ID,
                                  MY_NEW_ETO_ID);

                     EXCEPTION

                               WHEN OTHERS THEN
                                      MY_STATUS :='FAILED';
                                      MY_MSG :='Insert an audit record into KITT_AUDIT table for transfer event. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                      dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                       RAISE;
                      END;

                        -- Allocated fund back to the same subtask order with new ETO

                      Select SEQ_ALLOCATION.nextval into allocationID from dual;


                       BEGIN
                            Insert into  ALLOCATION
                                  ( N_ALLOCATION_ID,
                                    N_SUB_TASK_ORDER_ID,
                                    N_TASK_ORDER_BASE_ID,
                                    C_SUB_TASK_ORDER_NAME,
                                    N_USER_PROFILE_ID,
                                    N_DELPHI_OBLIGATION_ID,
                                    N_ETO_ID,
                                    N_ALLOCATION_AMOUNT,
                                    N_DEALLOCATION_AMOUNT,
                                    D_ALLOCATION_DATE,
                                    F_FEE)
                              values
                                   (allocationID,
                                    x.N_SUB_TASK_ORDER_ID,
                                    x.N_TASK_ORDER_BASE_ID,
                                    x.C_SUB_TASK_ORDER_NAME,
                                    MY_LOGINUSER_ID,
                                    x.N_DELPHI_OBLIGATION_ID,
                                    MY_NEW_ETO_ID,
                                    x.ALLOCATED_FUND,
                                    0,
                                    sysdate,
                                    x.F_FEE);

                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                            NULL;
                           WHEN OTHERS THEN
                                MY_STATUS :='FAILED';
                                MY_MSG :='Re-allocated fund amount '||x.ALLOCATED_FUND||' to SUBTO '||x.N_SUB_TASK_ORDER_ID||' for line '||x.N_DELPHI_OBLIGATION_ID||' with NEW ETO '||MY_NEW_ETO_ID||' in Allocation table.'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                               RAISE;
                      END;

                      dbms_output.put_line('Re-allocated fund amount '||x.ALLOCATED_FUND||' to SUBTO '||x.N_SUB_TASK_ORDER_ID||' for line '||x.N_DELPHI_OBLIGATION_ID||' with NEW ETO '||MY_NEW_ETO_ID||'.');

                    BEGIN
                      ETO_CHANGE_LOG ('ALLOCATION',
                                            x.N_SUB_TASK_ORDER_ID,
                                            x.N_DELPHI_OBLIGATION_ID,
                                            x.ALLOCATED_FUND,
                                            null,
                                            MY_NEW_ETO_ID,
                                            MY_LOGINUSER_ID);

                     EXCEPTION

                             WHEN OTHERS THEN
                                    MY_STATUS :='FAILED';
                                    MY_MSG :='Insert a log record into change eto log table for ALLOCATION. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                   dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                   RAISE;
                     END;

                     BEGIN

                      FIN_AUDIT ( 'allocate',
                                   allocationID,
                                   MY_LOGINUSER_ID,
                                   x.N_DELPHI_OBLIGATION_ID,
                                   x.N_SUB_TASK_ORDER_ID,
                                   x.N_TASK_ORDER_BASE_ID,
                                   x.C_SUB_TASK_ORDER_NAME,
                                   x.ALLOCATED_FUND,
                                   0,
                                   null,
                                   x.F_FEE,
                                   null,
                                   null,
                                   null);

                      EXCEPTION

                               WHEN OTHERS THEN
                                      MY_STATUS :='FAILED';
                                      MY_MSG :='Insert an audit record into KITT_AUDIT table for allocate event. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                      dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                       RAISE;
                      END;


                  end loop;



           else


              MY_STATUS :='FAILED';
              MY_MSG :='The new ETO doesn''t has the ETO role.';

           end if;


      else

           MY_STATUS :='FAILED';
           MY_MSG :='The old ETO doesn''t has the ETO role.';

      end if;

   EXCEPTION
     WHEN OTHERS THEN

        if MY_STATUS ='OK' then

                MY_STATUS :='FAILED';
                MY_MSG :=' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
        end if;
        dbms_output.put_line(' Status: '||MY_STATUS||' Msg: '||MY_MSG);

        SEND_SUPPORT_EMAIL ( 'CHANGE ETO', MY_MSG );
        MY_MSG :='UNSUCCESSFUL';
        dbms_output.put_line(' Status: '||MY_STATUS||' Msg: '||MY_MSG);

END FIN_TASK_FUND_CHANGE_ETO;


PROCEDURE FIN_XFER_UNALLOCATED_FUNDS (
                                      MY_OLD_ETO_ID    IN NUMBER,
                                      MY_NEW_ETO_ID    IN NUMBER,
                                      MY_USER_ID       IN NUMBER,
                                      MY_STATUS       OUT VARCHAR2,
                                      MY_MSG          OUT VARCHAR2)


IS

/******************************************************************************
   NAME:       FIN_XFER_UNALLOCATED_FUNDS
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/15/2010    Chao Yu      1. Created this procedure.
  1.1        4/14/2011    Chao Yu         2 . Add message in exception and pass and returen status from ETO_CHANGE_LOG procedure
   NOTES:

   This procedure will tranfer all un-allocated delphi line balance
   from one OLD ETO to NEW ETO

******************************************************************************/

ctn number;
transferID number;

BEGIN

      MY_STATUS :='OK';
      MY_MSG :='SUCCESSFUL';


     -- Verify the OLD_ETO_ID
     select count(*) into ctn
       from USER_PROFILE a, USER_ROLE b, SYSTEM_ROLE c
      where a.N_USER_PROFILE_ID =b.N_USER_PROFILE_ID
        and b.N_ROLE_NUMBER =c.N_ROLE_NUMBER
        and c.C_ROLE_LABEL ='ETO'
        and a.N_USER_PROFILE_ID =MY_OLD_ETO_ID;

      if ctn > 0 then

          -- Verify the NEW_ETO_ID
          select count(*) into ctn
            from USER_PROFILE a, USER_ROLE b, SYSTEM_ROLE c
           where a.N_USER_PROFILE_ID =b.N_USER_PROFILE_ID
             and b.N_ROLE_NUMBER =c.N_ROLE_NUMBER
             and c.C_ROLE_LABEL ='ETO'
             and a.N_USER_PROFILE_ID =MY_NEW_ETO_ID;


           if ctn > 0 then


                for c in ( select DELPHI_LINE_ID, PR_NUMBER, FEE_FLAG, LINE_BALANCE
                             from V_FIN_AVAIL_LINE_BAL_FOR_ETO
                            where ETO_ID = MY_OLD_ETO_ID
                              and LINE_BALANCE > 0 ) loop

                     select SEQ_TRANSFER.nextval into transferID from dual;



                        BEGIN

                               Insert into TRANSFER
                                 ( N_TRANSFER_ID,
                                   C_PR_NUMBER,
                                   N_DELPHI_OBLIGATION_ID,
                                   N_TRANSFER_AMOUNT,
                                   N_TRANSFER_FROM_ID,
                                   N_TRANSFER_TO_ID,
                                   N_USER_PROFILE_ID,
                                   D_TRANSFER_DATE,
                                   F_FEE )
                               Values
                                 (transferID,
                                  c.PR_NUMBER,
                                  c.DELPHI_LINE_ID,
                                  c.LINE_BALANCE,
                                  MY_OLD_ETO_ID,
                                  MY_NEW_ETO_ID,
                                  MY_USER_ID,
                                  sysdate,
                                  c.FEE_FLAG);

                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                            NULL;
                           WHEN OTHERS THEN
                                MY_STATUS :='FAILED';
                                MY_MSG :='Transfer fund amount '||c.LINE_BALANCE||' for line '||c.DELPHI_LINE_ID||'  from OLD ETO '||MY_OLD_ETO_ID||' to NEW ETO '||MY_NEW_ETO_ID||'. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                               dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                               RAISE;

                      END;

                     dbms_output.put_line('Transfer fund amount '||c.LINE_BALANCE||' for line '||c.DELPHI_LINE_ID||' from OLD ETO '||MY_OLD_ETO_ID||' to NEW ETO '||MY_NEW_ETO_ID||'.');

                 BEGIN
                      ETO_CHANGE_LOG ('TRANSFER UNALLOCATION',
                                            null,
                                            c.DELPHI_LINE_ID,
                                            c.LINE_BALANCE,
                                            MY_OLD_ETO_ID,
                                            MY_NEW_ETO_ID,
                                            MY_USER_ID);

                 EXCEPTION

                             WHEN OTHERS THEN
                                    MY_STATUS :='FAILED';
                                    MY_MSG :='Insert a log record into change eto log table for TRANSFER UNALLOCATION. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                   dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                   RAISE;
                     END;

                  BEGIN
                      FIN_AUDIT ( 'transfer',
                                  transferID,
                                  MY_USER_ID,
                                  c.DELPHI_LINE_ID,
                                  null,
                                  null,
                                  null,
                                  null,
                                  null,
                                  c.PR_NUMBER,
                                  c.FEE_FLAG,
                                  c.LINE_BALANCE,
                                  MY_OLD_ETO_ID,
                                  MY_NEW_ETO_ID);

                  EXCEPTION

                               WHEN OTHERS THEN
                                      MY_STATUS :='FAILED';
                                      MY_MSG :='Insert an audit record into KITT_AUDIT table for transfer event. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                                      dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
                                       RAISE;
                      END;

               end loop;


           else


              MY_STATUS :='FAILED';
              MY_MSG :='The new ETO doesn''t has the ETO role.';

           end if;


      else

           MY_STATUS :='FAILED';
           MY_MSG :='The old ETO doesn''t has the ETO role.';

      end if;

   EXCEPTION

     WHEN OTHERS THEN

        if MY_STATUS ='OK' then

                MY_STATUS :='FAILED';
                MY_MSG :=' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
        end if;

        dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
         SEND_SUPPORT_EMAIL ( 'CHANGE ETO', MY_MSG );
         MY_MSG :='UNSUCCESSFUL';
         dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);

END FIN_XFER_UNALLOCATED_FUNDS;

PROCEDURE   CHANGE_ETO ( new_eto_id number,
                         old_eto_id number,
                         user_id number)
IS

/******************************************************************************
   NAME:       CHANGE_ETO
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        08/04/2010               1. Created this procedure.

   NOTES:

   This procedure is used to change change old ETO to new ETO

******************************************************************************/

 MY_STATUS varchar2 ( 10);
 MY_MSG varchar2(2000);
 APPLICATION_EXCEPTION EXCEPTION;

BEGIN

     for c in ( select distinct N_TASK_ORDER_BASE_ID
                  from V_FIN_ETO_CHANGE_TO_LIST
                 where N_ETO_ID =old_eto_id ) loop


             FIN_TASK_FUND_CHANGE_ETO ( c.N_TASK_ORDER_BASE_ID,
                                        old_eto_id,
                                        new_eto_id,
                                        user_id,
                                        MY_STATUS,
                                        MY_MSG );


            if  MY_STATUS = 'FAILED' then

                 RAISE "APPLICATION_EXCEPTION";

            end if;

             update TASK_ORDER
                set N_ETO_ID = new_eto_id
              where N_TASK_ORDER_BASE_ID = c.N_TASK_ORDER_BASE_ID ;
              --  and N_TASK_ORDER_ID >= c.N_TASK_ORDER_ID;

     end loop;

     FIN_XFER_UNALLOCATED_FUNDS ( old_eto_id,
                                   new_eto_id,
                                   user_id,
                                   MY_STATUS,
                                   MY_MSG);

      if  MY_STATUS = 'FAILED' then

                 RAISE "APPLICATION_EXCEPTION";

      else
                commit;

      end if;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN "APPLICATION_EXCEPTION" THEN
        dbms_output.put_line(MY_MSG);
        ROLLBACK;
     WHEN OTHERS THEN
       ROLLBACK;
END CHANGE_ETO;

PROCEDURE FIN_LOAD_AWARDFEE IS

/******************************************************************************
   NAME:       FIN_LOAD_AWARDFEE
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        09/15/2010   Chao Yu       1. Created this procedure.

   NOTES:
    using for load award fee to db
******************************************************************************/

ctn number;
allocationID number;
transferID number;
dealloETOID number;
MY_MSG varchar2(1000);
MY_STATUS varchar2(20);
my_pr_number varchar2(30);


BEGIN

     MY_STATUS :='OK';
     MY_MSG :='SUCCESSFUL';

    -- The snapshot before processing


     for h in ( select a.N_SUB_TASK_ORDER_ID, (sum(a.N_ALLOCATION_AMOUNT) - sum(a.N_DEALLOCATION_AMOUNT)) as allocated_amount
                  from ALLOCATION a
                 where a.N_SUB_TASK_ORDER_ID in ( select distinct N_SUB_TASK_ORDER_ID
                                                    from ( select N_SUB_TASK_ORDER_ID from UTI_TEMP_AWARDFEE_DEALLO
                                                           Union all
                                                           select N_SUB_TASK_ORDER_ID from UTI_TEMP_AWARDFEE_ALLO
                                                         ))
                 group by a.N_SUB_TASK_ORDER_ID ) loop


           ETO_CHANGE_LOG ('PreProcess:AllocationTable',
                                 h.N_SUB_TASK_ORDER_ID,
                                 null,
                                 h.allocated_amount,
                                 null,
                                 null,
                                 null);

     end loop;

     for h in ( select N_SUB_TASK_ORDER_ID, sum(N_DEALLOCATION_AMOUNT) as DEALLOCATION_AMOUNT
                  from UTI_TEMP_AWARDFEE_DEALLO group by N_SUB_TASK_ORDER_ID ) loop


           ETO_CHANGE_LOG ('PreProcess:DeallocateTable',
                                 h.N_SUB_TASK_ORDER_ID,
                                 null,
                                 h.DEALLOCATION_AMOUNT,
                                 null,
                                 null,
                                 null);

     end loop;


        for h in ( select N_SUB_TASK_ORDER_ID, sum(N_ALLOCATION_AMOUNT) as ALLOCATION_AMOUNT
                  from UTI_TEMP_AWARDFEE_ALLO group by N_SUB_TASK_ORDER_ID ) loop


           ETO_CHANGE_LOG ('PreProcess:AllocateTable',
                                 h.N_SUB_TASK_ORDER_ID,
                                 null,
                                 h.ALLOCATION_AMOUNT,
                                 null,
                                 null,
                                 null);

     end loop;

     -- Only handle deallocation from one ETO. Get ETO ID
     select count(distinct c.N_ETO_ID) into ctn from UTI_TEMP_AWARDFEE_DEALLO a, sub_task_order b, task_order c
      where a.N_SUB_TASK_ORDER_ID = b.N_SUB_TASK_ORDER_ID
        and b.N_TASK_ORDER_ID = c.N_TASK_ORDER_ID;

    if ctn = 1 then

        -- Get ETO_ID
        select distinct c.N_ETO_ID into dealloETOID from UTI_TEMP_AWARDFEE_DEALLO a, sub_task_order b, task_order c
         where a.N_SUB_TASK_ORDER_ID = b.N_SUB_TASK_ORDER_ID
           and b.N_TASK_ORDER_ID = c.N_TASK_ORDER_ID;

        -- Check This ETO_ID allocated enough fund to this sub task order for each delphi line which will be deallocated

        select count(*) into ctn from
          (select a.N_SUB_TASK_ORDER_ID, a.N_DELPHI_OBLIGATION_ID, a.F_FEE, a.N_DEALLOCATION_AMOUNT,
                 b.ALLOCATED_FUND, (b.ALLOCATED_FUND - a.N_DEALLOCATION_AMOUNT) as Balance_diff
            from UTI_TEMP_AWARDFEE_DEALLO a,
                ( select * from  V_FIN_ALLO_FUND_FOR_SUBTO_ETO
                   where N_ETO_ID = dealloETOID)  b
            where a.N_SUB_TASK_ORDER_ID = b.N_SUB_TASK_ORDER_ID (+)
              and a.N_DELPHI_OBLIGATION_ID = b.N_DELPHI_OBLIGATION_ID (+)
              and a.F_FEE = b.F_FEE (+)) T
        where T.Balance_diff < 0;

      if ctn = 0 then

       -- Check there enough remaining balance for each sub task order and delphi line to deallocation

          select count(*) into ctn
           from
            ( SELECT a.n_sub_task_order_id, a.n_delphi_obligation_id, a.f_fee,
                    a.n_deallocation_amount, b.f_fee AS allo_fee_flag, b.remaining_fund,
                    b.remaining_fund - a.n_deallocation_amount AS balance_diff
               FROM UTI_TEMP_AWARDFEE_DEALLO a, v_revision_subto_remaining b
              WHERE a.n_sub_task_order_id = b.n_sub_task_order_id(+)
                AND a.n_delphi_obligation_id = b.n_delphi_obligation_id(+)
                AND a.f_fee=b.f_fee(+)) P
           where P.balance_diff < 0;


          if ctn = 0 then


            -- Check there are enough line balance to do re-allocation after the deallocation
            select  count(*) into ctn
              from
                (SELECT  m.n_sub_task_order_id, m.n_delphi_obligation_id,
                       m.f_fee, m.n_allocation_amount,
                       NVL (s.line_balance, 0) AS line_balance,
                       NVL (s.line_balance, 0) - m.n_allocation_amount AS balance_diff,
                        s.f_fee AS fee_flag
                 FROM UTI_TEMP_AWARDFEE_ALLO m,
                    (SELECT  a.n_delphi_obligation_id,
                             a.n_deallocation_amount AS line_balance, a.f_fee
                       FROM UTI_TEMP_AWARDFEE_DEALLO a
                  UNION ALL
                     SELECT p.delphi_line_id AS n_delphi_obligation_id, p.line_balance,
                            p.fee_flag AS f_fee
                       FROM v_fin_avail_line_bal_for_pmo p
                     WHERE p.pmo_id IN (dealloETOID, 100) AND p.line_balance > 0 ) s
                WHERE  m.n_delphi_obligation_id = s.n_delphi_obligation_id(+)) V

            where V.balance_diff < 0 ;

           if ctn = 0 then

                -- deallocation first
                for x in ( select N_SUB_TASK_ORDER_ID, N_DELPHI_OBLIGATION_ID, N_DEALLOCATION_AMOUNT, F_FEE
                             from UTI_TEMP_AWARDFEE_DEALLO ) loop

                      Select SEQ_ALLOCATION.nextval into allocationID from dual;

                      BEGIN

                       Insert into  ALLOCATION
                                  ( N_ALLOCATION_ID,
                                    N_SUB_TASK_ORDER_ID,
                                    N_USER_PROFILE_ID,
                                    N_DELPHI_OBLIGATION_ID,
                                    N_ETO_ID,
                                    N_ALLOCATION_AMOUNT,
                                    N_DEALLOCATION_AMOUNT,
                                    D_ALLOCATION_DATE,
                                    F_FEE)
                              values
                                   (allocationID,
                                    x.N_SUB_TASK_ORDER_ID,
                                    100,
                                    x.N_DELPHI_OBLIGATION_ID,
                                    dealloETOID,
                                    0,
                                    x.N_DEALLOCATION_AMOUNT,
                                    sysdate,
                                    x.F_FEE);

                      EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                            NULL;
                           WHEN OTHERS THEN
                                MY_STATUS :='FAILED';
                                MY_MSG :='De-allocated fund amount '||x.N_DEALLOCATION_AMOUNT||' from SUBTO '||x.N_SUB_TASK_ORDER_ID||' for line '||x.N_DELPHI_OBLIGATION_ID||' with the ETO '||dealloETOID||'in Allication table.'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                           RAISE;

                      END;

                      ETO_CHANGE_LOG ('DE-ALLOCATION',
                                            x.N_SUB_TASK_ORDER_ID,
                                            x.N_DELPHI_OBLIGATION_ID,
                                            x.N_DEALLOCATION_AMOUNT,
                                            dealloETOID,
                                            null,
                                            100);

                      dbms_output.put_line('De-allocated fund amount '||x.N_DEALLOCATION_AMOUNT||' from SUBTO '||x.N_SUB_TASK_ORDER_ID||' for line '||x.N_DELPHI_OBLIGATION_ID||' with the ETO '||dealloETOID||'.');

                      FIN_AUDIT ( 'deallocate',
                                   allocationID,
                                   100,
                                   x.N_DELPHI_OBLIGATION_ID,
                                   x.N_SUB_TASK_ORDER_ID,
                                   null,
                                   null,
                                   0,
                                   x.N_DEALLOCATION_AMOUNT,
                                   null,
                                   x.F_FEE,
                                   null,
                                   null,
                                   null);

                end loop;


                for y in ( SELECT  m.n_sub_task_order_id, m.n_delphi_obligation_id, m.n_allocation_amount,
                                   r.pmo_id, r.f_fee
                            FROM UTI_TEMP_AWARDFEE_ALLO m,
                                (SELECT p.pmo_id AS pmo_id,
                                        p.delphi_line_id AS n_delphi_obligation_id,
                                        p.fee_flag AS f_fee
                                   FROM v_fin_avail_line_bal_for_pmo p
                                  WHERE p.pmo_id IN (dealloETOID, 100) AND p.line_balance > 0) r
                           WHERE m.n_delphi_obligation_id = r.n_delphi_obligation_id(+)) loop



                   if y.pmo_id <>  dealloETOID then

                          -- Do the transfer first, then re-allocation


                          select C_PR_NUMBER into my_pr_number
                            from DELPHI_OBLIGATION
                           where N_DELPHI_OBLIGATION_ID = y.N_DELPHI_OBLIGATION_ID;



                           select SEQ_TRANSFER.nextval into transferID from dual;

                      BEGIN

                       Insert into TRANSFER
                                 ( N_TRANSFER_ID,
                                   C_PR_NUMBER,
                                   N_DELPHI_OBLIGATION_ID,
                                   N_TRANSFER_AMOUNT,
                                   N_TRANSFER_FROM_ID,
                                   N_TRANSFER_TO_ID,
                                   N_USER_PROFILE_ID,
                                   D_TRANSFER_DATE,
                                   F_FEE )
                               Values
                                 (transferID,
                                  my_pr_number,
                                  y.N_DELPHI_OBLIGATION_ID,
                                  y.n_allocation_amount,
                                  y.pmo_id,
                                  dealloETOID,
                                  100,
                                  sysdate,
                                  y.F_FEE);

                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                            NULL;
                           WHEN OTHERS THEN
                             MY_STATUS :='FAILED';
                                MY_MSG :='Transfer fund amount '||y.n_allocation_amount||' for line '||y.N_DELPHI_OBLIGATION_ID||' from the PMO '||y.pmo_id||' to NEW PMO '||dealloETOID||'. Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                           RAISE;

                      END;

                     dbms_output.put_line('Transfer fund amount '||y.n_allocation_amount||' for line '||y.N_DELPHI_OBLIGATION_ID||' from the PMO '||y.pmo_id||' to NEW ETO '||dealloETOID||'.');

                     ETO_CHANGE_LOG ('TRANSFER',
                                            y.N_SUB_TASK_ORDER_ID,
                                            y.N_DELPHI_OBLIGATION_ID,
                                            y.n_allocation_amount,
                                            y.pmo_id,
                                            dealloETOID,
                                            100);

                      FIN_AUDIT ( 'transfer',
                                  transferID,
                                  100,
                                  y.N_DELPHI_OBLIGATION_ID,
                                  null,
                                  null,
                                  null,
                                  null,
                                  null,
                                  my_pr_number,
                                  y.F_FEE,
                                  y.n_allocation_amount,
                                  y.pmo_id,
                                  dealloETOID);



                      end if;



                      -- ReAllocated fund back to other sub task order

                      Select SEQ_ALLOCATION.nextval into allocationID from dual;

                       BEGIN
                            Insert into  ALLOCATION
                                  ( N_ALLOCATION_ID,
                                    N_SUB_TASK_ORDER_ID,
                                    N_USER_PROFILE_ID,
                                    N_DELPHI_OBLIGATION_ID,
                                    N_ETO_ID,
                                    N_ALLOCATION_AMOUNT,
                                    N_DEALLOCATION_AMOUNT,
                                    D_ALLOCATION_DATE,
                                    F_FEE)
                              values
                                   (allocationID,
                                    y.N_SUB_TASK_ORDER_ID,
                                    100,
                                    y.N_DELPHI_OBLIGATION_ID,
                                    dealloETOID,
                                    y.n_allocation_amount,
                                    0,
                                    sysdate,
                                    y.F_FEE);

                       EXCEPTION
                           WHEN NO_DATA_FOUND THEN
                            NULL;
                           WHEN OTHERS THEN
                             MY_STATUS :='FAILED';
                                MY_MSG :='Re-allocated fund amount '||y.n_allocation_amount||' to SUBTO '||y.N_SUB_TASK_ORDER_ID||' for line '||y.N_DELPHI_OBLIGATION_ID||' with NEW ETO '||dealloETOID||'in Allication table.'||' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
                           RAISE;

                      END;

                      dbms_output.put_line('Re-allocated fund amount '||y.n_allocation_amount||' to SUBTO '||y.N_SUB_TASK_ORDER_ID||' for line '||y.N_DELPHI_OBLIGATION_ID||' with NEW ETO '||dealloETOID||'.');

                      ETO_CHANGE_LOG ('ALLOCATION',
                                            y.N_SUB_TASK_ORDER_ID,
                                            y.N_DELPHI_OBLIGATION_ID,
                                            y.n_allocation_amount,
                                            null,
                                            dealloETOID,
                                            100);

                      FIN_AUDIT ( 'allocate',
                                   allocationID,
                                   100,
                                   y.N_DELPHI_OBLIGATION_ID,
                                   y.N_SUB_TASK_ORDER_ID,
                                   null,
                                   null,
                                   y.n_allocation_amount,
                                   0,
                                   null,
                                   y.F_FEE,
                                   null,
                                   null,
                                   null);


                end loop;


          else

             MY_STATUS :='FAILED';
             MY_MSG:='There is no enough line balance to do re-allocation enve after deallocation.';


          end if;

        else

             MY_STATUS :='FAILED';
             MY_MSG:='There is no enough remaining balance to deallocation for each delphi line for this sub task order.';

        end if;

       else
          MY_STATUS :='FAILED';
          MY_MSG:='There is no enough fund to deallocation for this ETO for all delphi line for this sub task order.';

       end if;

     else

          MY_STATUS :='FAILED';
          MY_MSG:='Try to deallocation from more than one ETO/PMO';

     end if;

      if MY_STATUS ='OK' then

         commit;

      else

         rollback;

      end if;

      -- snapshot after process

        for h in ( select a.N_SUB_TASK_ORDER_ID, (sum(a.N_ALLOCATION_AMOUNT) - sum(a.N_DEALLOCATION_AMOUNT)) as allocated_amount
                  from ALLOCATION a
                 where a.N_SUB_TASK_ORDER_ID in ( select distinct N_SUB_TASK_ORDER_ID
                                                    from ( select N_SUB_TASK_ORDER_ID from UTI_TEMP_AWARDFEE_DEALLO
                                                           Union all
                                                           select N_SUB_TASK_ORDER_ID from UTI_TEMP_AWARDFEE_ALLO
                                                         ))
                 group by a.N_SUB_TASK_ORDER_ID ) loop


           ETO_CHANGE_LOG ('AfterProcess:AllocationTable',
                                 h.N_SUB_TASK_ORDER_ID,
                                 null,
                                 h.allocated_amount,
                                 null,
                                 null,
                                 null);

     end loop;

     commit;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       Rollback;
     WHEN OTHERS THEN
        if MY_STATUS ='OK' then
                MY_STATUS :='FAILED';
                MY_MSG :=' Error:'||to_char(SQLCODE) ||'-'||SQLERRM;
        end if;
        dbms_output.put_line('Status: '||MY_STATUS||' Msg: '||MY_MSG);
         Rollback;
END FIN_LOAD_AWARDFEE;

END PK_FINANCE;
/
