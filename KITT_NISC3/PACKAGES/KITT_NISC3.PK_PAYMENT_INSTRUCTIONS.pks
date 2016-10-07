DROP PACKAGE PK_PAYMENT_INSTRUCTIONS;

CREATE OR REPLACE PACKAGE            PK_PAYMENT_INSTRUCTIONS AS
  ---------------------------------------- PRIVATE METHODS
  -------------------- Please delete before deployment
  FUNCTION GET_SUBTASK_INFO( INVOICE_ITEM NUMBER ) RETURN VARCHAR2;

  ---------------------------------------- PUBLIC METHODS
  FUNCTION GENERATE( USER_ID NUMBER,
                     USER_ROLE VARCHAR2,
                     INVOICE NUMBER,
                     STATUS OUT VARCHAR2) RETURN NUMBER;
  PROCEDURE DELETE_PI( USER_ID NUMBER
                     , USER_ROLE VARCHAR2
                     , PAYMENT_INSTRUCTION NUMBER
                     , STATUS OUT VARCHAR2 );
  PROCEDURE PROCESS_CREDITS( PAYMENT_INSTRUCTION NUMBER, STATUS OUT VARCHAR2);
  PROCEDURE PROCESS_CHARGES( PAYMENT_INSTRUCTION NUMBER, STATUS OUT VARCHAR2);
END PK_PAYMENT_INSTRUCTIONS;
/

DROP PACKAGE BODY PK_PAYMENT_INSTRUCTIONS;

CREATE OR REPLACE PACKAGE BODY              "PK_PAYMENT_INSTRUCTIONS" AS
 LOG_DEBUG CHAR(1) := 'D';
 LOG_INFO CHAR(1) := 'I';
 LOG_WARN CHAR(1) := 'W';
 LOG_ERROR CHAR(1) := 'E';
 LOG_FATAL CHAR(1) := 'F';

 /******************* PRIVATE METHODS ***********************************/
 --------------------------------------------------------------------------
 -- PI_LOG
 --
 -- This generates a log message in the PAYMENT_INSTR_LOG table. It works
 -- much like Log4J in that an ERROR_LEVEL is passed in. The error level
 -- is defined as LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR and LOG_FATAL.
 --
 -- Just about any field can be put in as a NULL, and at some point it will.
 --------------------------------------------------------------------------
 PROCEDURE PI_LOG( ERROR_LEVEL CHAR
 , PAYMENT_INSTR NUMBER
 , INVOICE_ITEM NUMBER
 , AMOUNT NUMBER
 , MESSAGE VARCHAR2 ) AS

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

 BEGIN


 INSERT INTO PAYMENT_INSTR_LOG
 ( N_LOG_ID
 , C_ERROR_LEVEL
 , N_PAYMENT_INSTRUCTION_ID
 , N_INVOICE_ITEM_ID
 , N_AMOUNT
 , C_MESSAGE
 , D_REC_VERSION )
 VALUES
 ( SEQ_PAYMENT_INSTR_LOG.NEXTVAL
 , ERROR_LEVEL
 , PAYMENT_INSTR
 , INVOICE_ITEM
 , AMOUNT
 , MESSAGE
 , SYSDATE );
 DBMS_OUTPUT.PUT_LINE( MESSAGE );


 EXCEPTION
    WHEN OTHERS THEN

          lv_msg := SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'PI_LOG',
          'ERROR',
          'Error processing PI Log.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;


 END PI_LOG;

 --------------------------------------------------------------------------
 -- GET_SUBTASK_INFO
 --
 -- This function will take a subtask order ID, and return a string of the
 -- form 123.45/A
 --------------------------------------------------------------------------
 FUNCTION GET_SUBTASK_INFO( INVOICE_ITEM NUMBER ) RETURN VARCHAR2 AS
 v_TaskOrderNumber VARCHAR2(10);
 v_SubTaskName VARCHAR2(14);

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

 BEGIN


 SELECT T.C_TASK_ORDER_NUMBER, S.C_SUB_TASK_ORDER_NAME
 INTO v_TaskOrderNumber, v_SubTaskName
 FROM TASK_ORDER T, SUB_TASK_ORDER S, INVOICE_ITEM II
 WHERE T.N_TASK_ORDER_ID = S.N_TASK_ORDER_ID
 AND S.N_SUB_TASK_ORDER_ID = II.N_SUB_TASK_ORDER_ID
 AND II.N_INVOICE_ITEM_ID = INVOICE_ITEM;

 RETURN v_TaskOrderNumber || '/' || SUBSTR(v_SubTaskName, 9, 2);


 EXCEPTION
    WHEN OTHERS THEN

          lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'GET_SUBTASK_INFO',
          'ERROR',
          'Error processing Get Subtask Info.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;


 END GET_SUBTASK_INFO;

 --------------------------------------------------------------------------
 -- ADJUST_INVOICE
 --
 -- This procedure is simply there to create an invoice adjustment. You
 -- create Invoice Adjustments when processing a credit. The idea is, that
 -- if you are crediting money, that the money should be taken from the
 -- current invoice first, and then it goes back in time to previous
 -- invoices.
 -------------------------------------------------------------------------
 PROCEDURE ADJUST_INVOICE( INVOICE NUMBER
 , INVOICE_ITEM NUMBER
 , ADJUSTED_ITEM NUMBER
 , AMOUNT NUMBER ) AS

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

 BEGIN



 INSERT INTO INVOICE_ADJUSTMENT
 ( N_INVOICE_ID
 , N_INVOICE_ITEM_ID
 , N_ADJUSTED_ITEM_ID
 , N_ADJUSTED_AMOUNT
 , T_COMMENT
 , D_REC_VERSION )
 VALUES
 ( INVOICE, INVOICE_ITEM, ADJUSTED_ITEM, AMOUNT,
 'Adjusted $' || AMOUNT, SYSDATE);


 EXCEPTION
    WHEN OTHERS THEN

          lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'ADJUST_INVOICE',
          'ERROR',
          'Error processing Adjust Invoice.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;

 END ADJUST_INVOICE;

 --------------------------------------------------------------
 -- APPLY_CREDIT
 --
 -- This procedure will be called after we've exhausted all
 -- ability to adjust the invoice. This will generate a
 -- credit in the table. It is assumed that the credit
 -- validation has already happened by the caller.
 --------------------------------------------------------------
 PROCEDURE APPLY_CREDIT( INVOICE NUMBER
 , INVOICE_ITEM NUMBER
 , DELPHI NUMBER
 , F_FEE VARCHAR2
 , AMOUNT NUMBER ) AS

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;
 ETO_ID NUMBER;
 BEGIN




 SELECT T.N_ETO_ID INTO ETO_ID
 FROM SUB_TASK_ORDER S, TASK_ORDER T, INVOICE_ITEM II
 WHERE S.N_SUB_TASK_ORDER_ID = II.N_SUB_TASK_ORDER_ID
 AND S.N_TASK_ORDER_ID = T.N_TASK_ORDER_ID
 AND II.N_INVOICE_ITEM_ID = INVOICE_ITEM;

 INSERT INTO CREDIT
 ( N_INVOICE_ID
 , N_INVOICE_ITEM_ID
 , N_DELPHI_OBLIGATION_ID
 , N_ADJUSTED_AMOUNT
 , T_COMMENT
 , D_REC_VERSION
 , N_ETO_ID
 , F_FEE )
 VALUES
 ( INVOICE, INVOICE_ITEM, DELPHI, AMOUNT,
 'Credited $' || AMOUNT, SYSDATE, ETO_ID, F_FEE);

 EXCEPTION
    WHEN OTHERS THEN

        lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'APPLY_CREDIT',
          'ERROR',
          'Error processing Apply Credit.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;

 END APPLY_CREDIT;

 -------------------------------------------------------------------
 -- CREATE_PAYMENT_ITEM
 --
 -- This generates a single Payment Instruction Item within the
 -- Payment Instruction provided.
 -------------------------------------------------------------------
 PROCEDURE CREATE_PAYMENT_ITEM( PAYMENT_INST NUMBER
 , INVOICE_ITEM NUMBER
 , DELPHI NUMBER
 , AMOUNT NUMBER
 , FEE VARCHAR2 ) AS

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;
 PII_ID NUMBER;
 BEGIN
 SELECT SEQ_PAYMENT_INSTRUCTION_ITEM.NEXTVAL INTO PII_ID
 FROM DUAL;
 INSERT INTO PAYMENT_INSTRUCTION_ITEM
 ( N_PAYMENT_INSTRUCTION_ID
 , N_PAYMENT_INSTRUCTION_ITEM_ID
 , N_TASK_ORDER_BASE_ID
 , C_SUB_TASK_ORDER_NAME
 , N_SUB_TASK_ORDER_ID
 , N_DELPHI_OBLIGATION_ID
 , N_INVOICE_ITEM_ID
 , N_AMOUNT
 , F_FEE )
 SELECT PAYMENT_INST
 , PII_ID
 , II.N_TASK_ORDER_BASE_ID
 , II.C_SUB_TASK_ORDER_NAME
 , II.N_SUB_TASK_ORDER_ID
 , DELPHI
 , INVOICE_ITEM
 , AMOUNT
 , FEE
 FROM INVOICE_ITEM II
 WHERE II.N_INVOICE_ITEM_ID = INVOICE_ITEM;

 EXCEPTION
    WHEN OTHERS THEN

        lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'CREATE_PAYMENT_ITEM',
          'ERROR',
          'Error processing Create Payment Item.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;

 END CREATE_PAYMENT_ITEM;

 PROCEDURE CREATE_INVOICE_CERT_LETTER( USER_ID NUMBER
 , PAYMENT_INSTRUCTION NUMBER ) AS

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;
 BEGIN
 INSERT INTO INVOICE_CERTIFICATION_LETTER
 ( N_INVOICE_ID
 , N_PAYMENT_INSTRUCTION_ID
 , N_STATUS_NUMBER
 , N_OWNERSHIP_NUMBER
 , N_USER_PROFILE_ID
 , D_CREATED
 , D_REC_VERSION )
 SELECT N_INVOICE_ID, PAYMENT_INSTRUCTION, 102, 400,
 USER_ID, SYSDATE, SYSDATE
 FROM PAYMENT_INSTRUCTION PI
 WHERE PI.N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION;


 EXCEPTION
    WHEN OTHERS THEN

        lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'CREATE_INVOICE_CERT_LETTER',
          'ERROR',
          'Error processing Create Invoice Certification Letter',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;

 END CREATE_INVOICE_CERT_LETTER;


 -----------------------------------------------------------
 -- PROCESS_CREDIT
 --
 -- This procedure is called for each individual credit found
 -- on an invoice. It contains the logic for finding the
 -- Invoice Adjustments and Credits that need to be applied
 -- to the application.
 --
 -- First, it loops through all of the current charges on the
 -- invoice associated with the subtask of the Invoice Item.
 -- For each non-zero charge, it will adjust the item until
 -- either we've adjusted the credit to zero, or exhausted all
 -- the current invoices options.
 --
 -- Next, if there is still some credit left, it will look for
 -- delphi lines which are eligible to have a credit applied to
 -- them. It will loop through these lines, applying the credit
 -- as high as allowed, until the credit is satisfied - or we
 -- run out of funds.
 ----------------------------------------------------------
 PROCEDURE PROCESS_CREDIT( PAYMENT_INSTR NUMBER
 , INVOICE NUMBER
 , INVOICE_ITEM NUMBER
 , AMOUNT NUMBER
 , STATUS OUT VARCHAR2) AS

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;
 REMAINING_AMT NUMBER := -AMOUNT;
 BEGIN
 STATUS := 'Successful';

 /* Adjust the current invoice first */
 FOR CHARGE IN
 ( SELECT TABLE1.N_INVOICE_ITEM_ID
 , TABLE1.N_SUB_TASK_ORDER_ID
 , (TABLE1.N_FAA_COST+NVL(TABLE2.CREDIT,0)) AS AMOUNT
    FROM
 ( SELECT II_1.N_INVOICE_ITEM_ID
 , II_1.N_SUB_TASK_ORDER_ID
 , II_1.N_FAA_COST
 FROM INVOICE_ITEM II_1, INVOICE_ITEM II_2
     WHERE II_1.N_INVOICE_ID = INVOICE
 AND II_1.N_TASK_ORDER_BASE_ID = II_2.N_TASK_ORDER_BASE_ID
 AND II_1.C_SUB_TASK_ORDER_NAME = II_2.C_SUB_TASK_ORDER_NAME
 AND II_2.N_INVOICE_ITEM_ID = INVOICE_ITEM
 AND ((II_1.F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(II_1.F_PMO_DISPUTE_FLAG)='N'))
 AND (II_1.N_FAA_COST > 0)
 ) TABLE1,
    ( SELECT N_ADJUSTED_ITEM_ID,-SUM(N_ADJUSTED_AMOUNT) AS CREDIT
     FROM INVOICE_ADJUSTMENT
     WHERE N_INVOICE_ID = INVOICE
     GROUP BY N_ADJUSTED_ITEM_ID
 ) TABLE2
 WHERE TABLE1.N_INVOICE_ITEM_ID = TABLE2.N_ADJUSTED_ITEM_ID(+)
 ORDER BY AMOUNT DESC )
 LOOP
 IF (REMAINING_AMT > CHARGE.AMOUNT) THEN
 ADJUST_INVOICE( INVOICE, INVOICE_ITEM, CHARGE.N_INVOICE_ITEM_ID, CHARGE.AMOUNT );
 REMAINING_AMT := REMAINING_AMT - CHARGE.AMOUNT;
 ELSIF (REMAINING_AMT > 0) THEN
 ADJUST_INVOICE( INVOICE, INVOICE_ITEM, CHARGE.N_INVOICE_ITEM_ID, REMAINING_AMT );
 REMAINING_AMT := 0;
 END IF;
 END LOOP;
 IF (REMAINING_AMT > 0) THEN
 FOR DELPHI IN
(
	SELECT
		TABLE1.N_DELPHI_OBLIGATION_ID,
		TABLE1.AMOUNT,
		TABLE1.F_FEE,
		D.D_EXPIRATION_DATE
	 FROM
		(
			select
				T.n_delphi_obligation_id,
				amount,
				T.F_FEE,
				PP.F_PRIORITY
			from
				(
					SELECT
						N_DELPHI_OBLIGATION_ID,
						SUM(N_AMOUNT) AS AMOUNT,
						PII.F_FEE,
						II.N_INVOICE_ID,PII.N_TASK_ORDER_BASE_ID,PII.C_SUB_TASK_ORDER_NAME
					FROM
						PAYMENT_INSTRUCTION_ITEM PII, INVOICE_ITEM II
					WHERE
						PII.N_TASK_ORDER_BASE_ID = II.N_TASK_ORDER_BASE_ID
						AND PII.C_SUB_TASK_ORDER_NAME = II.C_SUB_TASK_ORDER_NAME
						AND II.N_INVOICE_ITEM_ID = INVOICE_ITEM
					GROUP BY
						PII.N_TASK_ORDER_BASE_ID,
						PII.C_SUB_TASK_ORDER_NAME,
						II.N_INVOICE_ID,
						N_DELPHI_OBLIGATION_ID,
						PII.F_FEE
				) T
				left outer join payment_prioritization pp on
						PP.n_delphi_obligation_id=T.n_delphi_obligation_id
				--	AND	PP.N_INVOICE_ID=T.N_INVOICE_ID
					AND	PP.N_TASK_ORDER_BASE_ID=T.N_TASK_ORDER_BASE_ID
					AND	PP.C_SUB_TASK_ORDER_NAME=T.C_SUB_TASK_ORDER_NAME
		) TABLE1,
		DELPHI_OBLIGATION D,
		(
			SELECT
				N_DELPHI_OBLIGATION_ID,
				SUM(N_ADJUSTED_AMOUNT) AS ADJUSTED_AMOUNT
			FROM
				DELPHI_OBLIGATION_ADJUSTMENT
			GROUP BY
				N_DELPHI_OBLIGATION_ID
		) TABLE3
	 WHERE
		TABLE1.N_DELPHI_OBLIGATION_ID = D.N_DELPHI_OBLIGATION_ID
	 AND	D.N_DELPHI_OBLIGATION_ID = TABLE3.N_DELPHI_OBLIGATION_ID (+)
	 AND	TABLE1.F_PRIORITY IS NULL
	 ORDER BY
		D.D_EXPIRATION_DATE DESC,
		(TABLE1.AMOUNT - TABLE3.ADJUSTED_AMOUNT) DESC,
		TABLE1.F_PRIORITY ASC
)
LOOP

 INSERT INTO PROCESS_CREDIT_LOG
          ( N_INVOICE_ID,
            N_INVOICE_ITEM_ID,
            N_REMAINING_AMT,
            N_PAID_AMT,
            N_DELPHI_OBLIGATION_ID,
            D_REC_VERSION)
          VALUES
          (INVOICE,
          INVOICE_ITEM,
          REMAINING_AMT,
          DELPHI.AMOUNT,
          DELPHI.N_DELPHI_OBLIGATION_ID,
          SYSDATE
           );

IF (REMAINING_AMT > DELPHI.AMOUNT) THEN
APPLY_CREDIT( INVOICE, INVOICE_ITEM,
DELPHI.N_DELPHI_OBLIGATION_ID, DELPHI.F_FEE,
DELPHI.AMOUNT );
REMAINING_AMT := REMAINING_AMT - DELPHI.AMOUNT;
ELSIF (REMAINING_AMT > 0) THEN
APPLY_CREDIT( INVOICE, INVOICE_ITEM,
DELPHI.N_DELPHI_OBLIGATION_ID, DELPHI.F_FEE,
REMAINING_AMT );
REMAINING_AMT := 0;
END IF;
END LOOP;
END IF;


 IF (REMAINING_AMT > 0) THEN
 STATUS := 'FAIL: Unable to complete credit for ' ||
 GET_SUBTASK_INFO(INVOICE_ITEM) || ' $' || REMAINING_AMT ||
 ' remains. Invoice Item# ' || INVOICE_ITEM;
 PI_LOG( LOG_ERROR, PAYMENT_INSTR, INVOICE_ITEM,
 REMAINING_AMT, STATUS );
 END IF;


 EXCEPTION
    WHEN OTHERS THEN

        lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'PROCESS_CREDIT',
          'ERROR',
          'Error processing Process Credit',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;

 END PROCESS_CREDIT;

 --------------------------------------------------------------
 -- PROCESS_CHARGE
 --
 -- This procedure is called to find the proper allocations to
 -- use to cover a charge on an invoice. But, before we do that
 -- we need to determine if there are any adjustments to the Invoice
 -- item.
 -------------------------------------------------------------
 PROCEDURE PROCESS_CHARGE( PAYMENT_INST NUMBER
 , INVOICE NUMBER
 , INVOICE_ITEM NUMBER
 , AMOUNT NUMBER
 , STATUS OUT VARCHAR2) AS
 REMAINING_AMT NUMBER := AMOUNT;
 ADJUSTMENT_AMT NUMBER;

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;
 BEGIN
 STATUS := 'Successful';

 SELECT SUM(N_ADJUSTED_AMOUNT) INTO ADJUSTMENT_AMT
 FROM INVOICE_ADJUSTMENT
 WHERE N_ADJUSTED_ITEM_ID = INVOICE_ITEM;

 IF (ADJUSTMENT_AMT IS NOT NULL) THEN
 REMAINING_AMT := REMAINING_AMT - ADJUSTMENT_AMT;
 END IF;

 FOR ALLOC IN
 ( SELECT
		Table1.n_delphi_obligation_id,
		SUM(amount) AS AMOUNT,
		D.D_EXPIRATION_DATE,
		Table1.F_FEE
	 FROM
		(
			select
				T.n_delphi_obligation_id,
				amount,
				T.F_FEE,
				PP.F_PRIORITY
			from
				(
					SELECT A.n_delphi_obligation_id
					 , n_allocation_amount - n_deallocation_amount as amount
					 , A.F_FEE,II.N_INVOICE_ID,II.N_TASK_ORDER_BASE_ID,II.C_SUB_TASK_ORDER_NAME
					 FROM allocation A, invoice_item ii
					 WHERE II.N_INVOICE_ITEM_ID = INVOICE_ITEM
					 AND A.N_TASK_ORDER_BASE_ID = II.N_TASK_ORDER_BASE_ID
					 AND A.C_SUB_TASK_ORDER_NAME = II.C_SUB_TASK_ORDER_NAME
					 UNION ALL
					 SELECT p.n_delphi_obligation_id
					 , -n_amount AS amount
					 , F_FEE
					 ,II.N_INVOICE_ID,II.N_TASK_ORDER_BASE_ID,II.C_SUB_TASK_ORDER_NAME
					 FROM payment_instruction_item p, INVOICE_ITEM II
					 WHERE II.N_INVOICE_ITEM_ID = INVOICE_ITEM
					 AND P.N_TASK_ORDER_BASE_ID = II.N_TASK_ORDER_BASE_ID
					 AND P.C_SUB_TASK_ORDER_NAME = II.C_SUB_TASK_ORDER_NAME
					 UNION ALL
					 SELECT CRED.N_DELPHI_OBLIGATION_ID
					 , CRED.N_ADJUSTED_AMOUNT AS AMOUNT
					 , NVL(F_FEE,'N') AS F_FEE
					 ,II_1.N_INVOICE_ID,II_1.N_TASK_ORDER_BASE_ID,II_1.C_SUB_TASK_ORDER_NAME
					 FROM CREDIT CRED, INVOICE_ITEM II_1, INVOICE_ITEM II_2
					 WHERE CRED.N_INVOICE_ITEM_ID = II_1.N_INVOICE_ITEM_ID
					 AND II_1.N_TASK_ORDER_BASE_ID = II_2.N_TASK_ORDER_BASE_ID
					 AND II_1.C_SUB_TASK_ORDER_NAME = II_2.C_SUB_TASK_ORDER_NAME
					 AND II_2.N_INVOICE_ITEM_ID = INVOICE_ITEM
				) T
				left outer join payment_prioritization pp on
						PP.n_delphi_obligation_id=T.n_delphi_obligation_id
					-- AND	PP.N_INVOICE_ID=T.N_INVOICE_ID
					 AND	PP.N_TASK_ORDER_BASE_ID=T.N_TASK_ORDER_BASE_ID
					 AND	PP.C_SUB_TASK_ORDER_NAME=T.C_SUB_TASK_ORDER_NAME
					 AND	PP.F_PRIORITY='Y'
		) TABLE1,
		DELPHI_OBLIGATION D
	 WHERE
		Table1.n_delphi_obligation_id = D.N_DELPHI_OBLIGATION_ID
	 GROUP BY
		TABLE1.N_DELPHI_OBLIGATION_ID,
		TABLE1.F_FEE,
		D.D_EXPIRATION_DATE,
		table1.f_priority
	 HAVING
		SUM(AMOUNT) > 0
	 ORDER BY
		Table1.F_PRIORITY ASC,
		D.D_Expiration_date ASC,
		Table1.n_delphi_obligation_id,
		AMOUNT
 )
 LOOP
 IF (REMAINING_AMT > ALLOC.AMOUNT) THEN
 CREATE_PAYMENT_ITEM( PAYMENT_INST, INVOICE_ITEM,
 ALLOC.N_DELPHI_OBLIGATION_ID, ALLOC.AMOUNT,
 ALLOC.F_FEE );
 REMAINING_AMT := REMAINING_AMT - ALLOC.AMOUNT;
 ELSIF (REMAINING_AMT > 0) THEN
 CREATE_PAYMENT_ITEM( PAYMENT_INST, INVOICE_ITEM,
 ALLOC.N_DELPHI_OBLIGATION_ID, REMAINING_AMT,
 ALLOC.F_FEE );
 REMAINING_AMT := 0;
 END IF;
 END LOOP;

 IF (REMAINING_AMT > 0) THEN
 STATUS := 'FAIL: Insufficient funds to cover $'|| REMAINING_AMT ||
 '. Subtask: ' ||
 GET_SUBTASK_INFO( INVOICE_ITEM ) || ' Invoice Item#: ' || INVOICE_ITEM;
 PI_LOG( LOG_ERROR, PAYMENT_INST, INVOICE_ITEM,
 REMAINING_AMT, STATUS );
 END IF;

 EXCEPTION
    WHEN OTHERS THEN

        lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'PROCESS_CHARGE',
          'ERROR',
          'Error processing Process Charge.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;



 END PROCESS_CHARGE;

 /*************** PUBLIC METHODS *************************************/
 -------------------------------------------------
 -- GENERATE
 --
 -- This method is called to generate the Payment
 -- Instructions.
 --
 -- It needs to validate the user.
 -- Create the Payment Instruction header record.
 -- Process the credits.
 -- Process the charges.
 -- Return a message in the STATUS field.
 -- Return the Payment Instruction ID from the function.
 ------------------------------------------------
 FUNCTION GENERATE( USER_ID NUMBER,
 USER_ROLE VARCHAR2,
 INVOICE NUMBER,
 STATUS OUT VARCHAR2) RETURN NUMBER AS
 v_OldPaymentInstruction NUMBER := NULL;
 v_PaymentInstruction NUMBER := -1;
 v_Status VARCHAR2(1000);
 v_InvoiceStatus NUMBER;
 v_Authorized CHAR;

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

 BEGIN
 STATUS := 'Successful';
 v_Authorized := PK_SECURITY.AUTHORIZED(USER_ID, USER_ROLE, 'PMO');
 IF( v_Authorized != 'Y') THEN
 STATUS := 'FAIL: User not authorized to perform this operation.';
 RETURN -1;
 END IF;

 SELECT N_STATUS_NUMBER INTO v_InvoiceStatus
 FROM INVOICE
 WHERE N_INVOICE_ID = INVOICE;

 IF (v_InvoiceStatus != 305) THEN
 STATUS := 'FAIL: Invoice needs to be in PMO Certified state.';
 DBMS_OUTPUT.PUT_LINE( STATUS );
 RETURN -1;
 END IF;

 BEGIN
 SELECT N_PAYMENT_INSTRUCTION_ID INTO v_OldPaymentInstruction
 FROM PAYMENT_INSTRUCTION
 WHERE N_INVOICE_ID = INVOICE;

 DELETE_PI( USER_ID, USER_ROLE, v_OldPaymentInstruction, v_Status );
 IF (v_Status != 'Successful') THEN
 STATUS := v_Status;
 RETURN -1;
 END IF;
 EXCEPTION
 WHEN NO_DATA_FOUND THEN
 NULL;
 END;

 SELECT SEQ_PAYMENT_INSTRUCTION.NEXTVAL INTO v_PaymentInstruction
 FROM DUAL;
 INSERT INTO PAYMENT_INSTRUCTION
 ( N_PAYMENT_INSTRUCTION_ID
 , N_INVOICE_ID
 , N_USER_PROFILE_ID
 , D_REC_VERSION )
 VALUES
 ( v_PaymentInstruction, INVOICE, USER_ID, SYSDATE );

 PROCESS_CREDITS( v_PaymentInstruction, v_Status );
 IF (v_Status != 'Successful') THEN
 STATUS := v_Status;
 -- RETURN v_PaymentInstruction;
 END IF;

 PROCESS_CHARGES( v_PaymentInstruction, v_Status );
 IF (v_Status != 'Successful') THEN
 STATUS := v_Status;
-- RETURN v_PaymentInstruction;
 END IF;

 IF (STATUS != 'Successful') THEN
 DELETE_PI( USER_ID, USER_ROLE, v_PaymentInstruction, v_Status );
 RETURN v_PaymentInstruction;
 END IF;

 CREATE_INVOICE_CERT_LETTER( USER_ID, v_PaymentInstruction );

 UPDATE INVOICE
 SET N_STATUS_NUMBER = 306, C_INVOICE_STATUS = 'Payment Instruction Created'
 WHERE N_INVOICE_ID = INVOICE;

 RETURN v_PaymentInstruction;

 EXCEPTION
    WHEN OTHERS THEN

          STATUS := 'FAIL: Check Logs';
          lv_msg :=  SQLERRM;

          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'GENERATE',
          'ERROR',
          'Error processing Payment Instruction Log.',
          lv_msg,
          NULL,
          SYSDATE
           );
       COMMIT;
       RETURN v_PaymentInstruction;

 END GENERATE;

 ----------------------------------------------------------------
 -- PROCESS_CREDIT
 --
 -- This procedure will loop over the un-disputed invoice items of
 -- the invoice pointed to by the Payment Instructions. It also
 -- only looks at those with a value less than zero (i.e. a credit.)
 --
 -- For each credit, it calls PROCESS_CREDIT to try and resolve it.
 ---------------------------------------------------------------
 PROCEDURE PROCESS_CREDITS( PAYMENT_INSTRUCTION NUMBER, STATUS OUT VARCHAR2) AS
 v_Status VARCHAR2(1000);

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;
 BEGIN
 STATUS := 'Successful';

 FOR CREDIT IN
 ( SELECT II.N_INVOICE_ID, II.N_INVOICE_ITEM_ID, II.N_FAA_COST
 FROM INVOICE_ITEM II, PAYMENT_INSTRUCTION PI
 WHERE II.N_INVOICE_ID = PI.N_INVOICE_ID
 AND PI.N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION
 AND ((F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(F_PMO_DISPUTE_FLAG)='N'))
 AND (N_FAA_COST < 0)
 ORDER BY N_FAA_COST )
 LOOP
 PROCESS_CREDIT( PAYMENT_INSTRUCTION
 , CREDIT.N_INVOICE_ID
 , CREDIT.N_INVOICE_ITEM_ID
 , CREDIT.N_FAA_COST
 , v_Status);
 IF (v_Status != 'Successful') THEN
 STATUS := 'FAIL: Unable to process credits. Check database for log.';
 END IF;
 END LOOP;
 IF (STATUS != 'Successful') THEN
 PI_LOG( LOG_INFO, PAYMENT_INSTRUCTION, NULL, NULL, STATUS );
 RETURN;
 END IF;

 EXCEPTION
    WHEN OTHERS THEN

        lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'PROCESS_CREDITS',
          'ERROR',
          'Error processing Process Credits.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;


 END PROCESS_CREDITS;

 ---------------------------------------------------------------
 -- PROCESS_CHARGES
 --
 -- This loops through all the positive charges in the invoice
 -- pointed to by the Payment Instruction, and calls "PROCESS_CHARGE" on
 -- them. PROCESS_CHARGE then goes and identifies allocations which
 -- can be charged against.
 ---------------------------------------------------------------
 PROCEDURE PROCESS_CHARGES( PAYMENT_INSTRUCTION NUMBER, STATUS OUT VARCHAR2) AS
 v_Status VARCHAR2(1000);

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;
 BEGIN
 FOR CHARGE IN
 ( SELECT II.N_INVOICE_ID, II.N_INVOICE_ITEM_ID, II.N_FAA_COST
 FROM INVOICE_ITEM II, PAYMENT_INSTRUCTION PI
 WHERE II.N_INVOICE_ID = PI.N_INVOICE_ID
 AND PI.N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION
 AND ((F_PMO_DISPUTE_FLAG IS NULL) OR (UPPER(F_PMO_DISPUTE_FLAG)='N'))
 AND (N_FAA_COST > 0)
 ORDER BY N_FAA_COST )
 LOOP
 PROCESS_CHARGE( PAYMENT_INSTRUCTION
 , CHARGE.N_INVOICE_ID
 , CHARGE.N_INVOICE_ITEM_ID
 , CHARGE.N_FAA_COST
 , v_Status);
 IF (v_Status != 'Successful') THEN
 STATUS := 'FAIL: Unable to process charges. Check database for log.';
 END IF;
 END LOOP;
 IF (STATUS != 'Successful') THEN
 PI_LOG( LOG_INFO, PAYMENT_INSTRUCTION, NULL, NULL, STATUS );
 RETURN;
 END IF;


 EXCEPTION
    WHEN OTHERS THEN

        lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'PROCESS_CHARGES',
          'ERROR',
          'Error processing Process Charges.',
          lv_msg,
          NULL,
          SYSDATE
           );

       RAISE;

 END PROCESS_CHARGES;

 -------------------------------------------------------------------
 -- DELETE_PI
 --
 -- This procedure will delete all the information about a Payment
 -- Instruction, and move the invoice back to the PMO Certified state.
 -------------------------------------------------------------------
 PROCEDURE DELETE_PI( USER_ID NUMBER
 , USER_ROLE VARCHAR2
 , PAYMENT_INSTRUCTION NUMBER
 , STATUS OUT VARCHAR2 ) AS
 v_InvoiceStatus NUMBER;
 v_Authorized CHAR;

 lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

 BEGIN


  v_Authorized := PK_SECURITY.AUTHORIZED(USER_ID, USER_ROLE, 'PMO');
 IF( v_Authorized != 'Y') THEN
 STATUS := 'FAIL: User not authorized to perform this operation.';
 RETURN;
 END IF;

 SELECT N_STATUS_NUMBER INTO v_InvoiceStatus
 FROM INVOICE I, PAYMENT_INSTRUCTION PI
 WHERE I.N_INVOICE_ID = PI.N_INVOICE_ID
 AND PI.N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION;

 IF (v_InvoiceStatus NOT IN (305, 306)) THEN
 STATUS := 'FAIL: Invoice must be in Payment Instructions Created or PMO Certified state.';
 DBMS_OUTPUT.PUT_LINE( STATUS );
 RETURN;
 END IF;

 DELETE FROM PAYMENT_INSTRUCTION_ITEM
 WHERE N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION;

 DELETE FROM INVOICE_CERTIFICATION_LETTER
 WHERE N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION;

 DELETE FROM CREDIT
 WHERE N_INVOICE_ITEM_ID IN
 ( SELECT N_INVOICE_ITEM_ID
 FROM INVOICE_ITEM II, PAYMENT_INSTRUCTION PI
 WHERE II.N_INVOICE_ID = PI.N_INVOICE_ID
 AND PI.N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION );

 DELETE FROM INVOICE_ADJUSTMENT
 WHERE N_INVOICE_ITEM_ID IN
 ( SELECT N_INVOICE_ITEM_ID
 FROM INVOICE_ITEM II, PAYMENT_INSTRUCTION PI
 WHERE II.N_INVOICE_ID = PI.N_INVOICE_ID
 AND PI.N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION );

 UPDATE INVOICE
 SET N_STATUS_NUMBER = 305, C_INVOICE_STATUS = 'PMO Certified'
 WHERE N_INVOICE_ID IN
 ( SELECT N_INVOICE_ID
 FROM PAYMENT_INSTRUCTION
 WHERE N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION);

 DELETE FROM PAYMENT_INSTRUCTION
 WHERE N_PAYMENT_INSTRUCTION_ID = PAYMENT_INSTRUCTION;

 STATUS := 'Successful';
 RETURN;


EXCEPTION
    WHEN OTHERS THEN

          lv_msg :=  SQLERRM;
          --
          -- Log error
          --
          INSERT INTO KITT_LOG
          ( N_LOG_ID,
            N_CONTRACT_ID,
            C_PROGRAM_NAME,
            C_MODULE_NAME,
            F_LOG_CATEGORY,
            C_MESSAGE,
            C_DESCRIPTION,
            B_STACKTRACE,
            D_REC_VERSION)
          VALUES
          (SEQ_KITT_LOG.NEXTVAL,
          101,
          'PK_PAYMENT_INSTRUCTIONS',
          'DELETE_PI',
          'ERROR',
          'Error processing Delete PI.',
          NULL,
          lv_msg,
          SYSDATE
           );

       RAISE;

 END DELETE_PI;
END PK_PAYMENT_INSTRUCTIONS;
/
