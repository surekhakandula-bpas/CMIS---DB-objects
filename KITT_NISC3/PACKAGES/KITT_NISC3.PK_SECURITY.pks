DROP PACKAGE PK_SECURITY;

CREATE OR REPLACE PACKAGE              "PK_SECURITY" AS
  DEFAULT_DURATION number := 300;
  -------------------------------------------------------
  -- HAS_ROLE
  --
  -- This will simply determine if the User ID provided
  -- has the requested role or not.  If it does, it returns
  -- 'Y' - otherwise it returns 'N'
  -------------------------------------------------------
  FUNCTION HAS_ROLE( USER_ID NUMBER
                   , USER_ROLE VARCHAR2 ) RETURN CHAR;

  -------------------------------------------------------
  -- AUTHORIZED
  --
  -- This method is more complicated than HAS_ROLE.  It
  -- basically does two checks.  The first, is that if
  -- the USER_ROLE provided is one of the authorized roles
  -- (provided as a comma seperated list in AUTH_ROLES).
  --
  -- Once it determines the USER_ROLE is O.K., then it
  -- verifies that the user indeed has the role.
  --
  -- Returns 'Y' if all the criteria are true.  'N' otherwise.
  -------------------------------------------------------
  FUNCTION AUTHORIZED( USER_ID NUMBER
                     , USER_ROLE VARCHAR2
                     , AUTH_ROLES VARCHAR2 ) RETURN CHAR;

  -------------------------------------------------------
  -- ISSUE_TOKEN
  --
  -- This method will issue a security token for a user
  -- which can be used to authenticate into the system
  -- without a password.  Default duration is 5 minutes.
  -------------------------------------------------------
  FUNCTION ISSUE_TOKEN( USER_ID NUMBER
                      , DURATION_IN_SEC NUMBER := DEFAULT_DURATION )
    RETURN RAW;

  -------------------------------------------------------
  -- VALIDATE_TOKEN
  --
  -- This method will ensure that the User ID and Token provided
  -- are valid.
  -- Returns 'Y' if it is valid.  'N' if it isn't.
  -------------------------------------------------------
  FUNCTION VALIDATE_TOKEN( USER_ID NUMBER, TOKEN RAW )
    RETURN CHAR;

  -------------------------------------------------------
  -- PURGE_TOKEN
  --
  -- This method will delete any expired tokens from the
  -- SECURITY_TOKEN table.
  -------------------------------------------------------
  PROCEDURE PURGE_TOKEN;
END PK_SECURITY;
/

DROP PACKAGE BODY PK_SECURITY;

CREATE OR REPLACE PACKAGE BODY              "PK_SECURITY" AS
  FUNCTION CHECK_ROLE( p_Role VARCHAR2, p_List VARCHAR2, p_Delim VARCHAR2 := ',' )
      RETURN CHAR AS
    l_Index PLS_INTEGER;
    l_List VARCHAR2(32767) := p_List;
    l_Value VARCHAR2(32767);
  BEGIN
    LOOP
      l_Index := INSTR( l_List, p_Delim );
      IF (l_Index > 0) THEN
        l_Value := SUBSTR(l_List, 1, l_Index - 1);
        l_List := SUBSTR(l_List, l_Index + LENGTH(p_Delim));
        DBMS_OUTPUT.PUT_LINE( l_Value );
      ELSE
        l_Value := l_List;
      END IF;

      IF (p_Role = l_Value) THEN
        RETURN 'Y';
      END IF;
      IF (l_Index <= 0) THEN
        EXIT;
      END IF;
    END LOOP;
    RETURN 'N';
  END CHECK_ROLE;

  /********* PUBLIC METHODS ***************/
  FUNCTION HAS_ROLE( USER_ID NUMBER
                   , USER_ROLE VARCHAR2 ) RETURN CHAR AS
    v_RoleCount NUMBER := 0;
    lv_msg     KITT_LOG.C_DESCRIPTION%TYPE;

  BEGIN
    SELECT COUNT(*) INTO v_RoleCount
      FROM USER_ROLE UR, SYSTEM_ROLE SR
     WHERE UR.N_USER_PROFILE_ID = USER_ID
       AND UR.N_ROLE_NUMBER = SR.N_ROLE_NUMBER
       AND SR.C_ROLE_LABEL = USER_ROLE
       AND UR.C_ROLE_STATUS = 'Approved';

    IF (v_RoleCount > 0) THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
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
          'PK SECURITY.HAS_ROLE',
          NULL,
          'ERROR',
          'Error processing PK SECURITY.HAS_ROLE.',
          lv_msg,
          NULL,
          SYSDATE
           );
       COMMIT;
       RAISE;

  END HAS_ROLE;

  FUNCTION AUTHORIZED( USER_ID NUMBER
                     , USER_ROLE VARCHAR2
                     , AUTH_ROLES VARCHAR2 ) RETURN CHAR AS
    v_RoleCount NUMBER := 0;
  BEGIN
    IF (CHECK_ROLE( USER_ROLE, AUTH_ROLES ) = 'Y') THEN
      RETURN HAS_ROLE( USER_ID, USER_ROLE );
    ELSE
      RETURN 'N';
    END IF;
  END AUTHORIZED;

  -------------------------------------------------------
  -- ISSUE_TOKEN
  --
  -- This method will issue a security token for a user
  -- which can be used to authenticate into the system
  -- without a password.  Default duration is 5 minutes.
  -------------------------------------------------------
  FUNCTION ISSUE_TOKEN( USER_ID NUMBER
                      , DURATION_IN_SEC NUMBER := DEFAULT_DURATION )
                            RETURN RAW IS
    RC RAW(32);
  BEGIN
    RC := DBMS_CRYPTO.RANDOMBYTES(32);
    DELETE FROM SECURITY_TOKEN WHERE N_USER_PROFILE_ID = USER_ID;
    INSERT INTO SECURITY_TOKEN (N_USER_PROFILE_ID, D_EXPIRATION, R_TOKEN)
      VALUES
    ( USER_ID, SYSDATE + (DURATION_IN_SEC / (24 * 60 * 60)), RC);
    RETURN RC;
  END ISSUE_TOKEN;

  -------------------------------------------------------
  -- VALIDATE_TOKEN
  --
  -- This method will ensure that the User ID and Token provided
  -- are valid.
  -- Returns 'Y' if it is valid.  'N' if it isn't.
  -------------------------------------------------------
  FUNCTION VALIDATE_TOKEN( USER_ID NUMBER
                         , TOKEN RAW ) RETURN CHAR IS
    ISSUED_TOKEN RAW(32);
  BEGIN
    SELECT R_TOKEN INTO ISSUED_TOKEN
      FROM SECURITY_TOKEN
     WHERE N_USER_PROFILE_ID = USER_ID
       AND D_EXPIRATION > SYSDATE;
    IF ISSUED_TOKEN = TOKEN THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'N';
  END VALIDATE_TOKEN;

  -------------------------------------------------------
  -- PURGE_TOKEN
  --
  -- This method will delete any expired tokens from the
  -- SECURITY_TOKEN table.
  -------------------------------------------------------
  PROCEDURE PURGE_TOKEN IS
  BEGIN
    DELETE FROM SECURITY_TOKEN WHERE D_EXPIRATION < SYSDATE;
  END PURGE_TOKEN;
END PK_SECURITY;
/
