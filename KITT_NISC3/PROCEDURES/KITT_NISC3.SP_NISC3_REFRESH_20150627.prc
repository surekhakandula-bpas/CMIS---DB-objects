DROP PROCEDURE SP_NISC3_REFRESH_20150627;

CREATE OR REPLACE PROCEDURE            SP_NISC3_REFRESH_20150627
--(
--                        p_PStatus          OUT VARCHAR2 )  
/*
---------------------------------------------------------------------------------------------------
  Object Name:  SP_NISC3_REFRESH
  Author:       J Feld
  Date Created: 06/15/2015    
  Purpose: Refresh Prod Mirror from production KITTD
  
  Modification History:
---------------------------------------------------------------------------------------------------  
*/                              
IS
--  vCount          NUMBER :=0 ;  
  vSENDER         VARCHAR2(200);
  vRECEIVER       VARCHAR2(200);
  vSUBJECT        VARCHAR2(200);
  vMESSAGE        VARCHAR2(32000); 
  vEMAIL          VARCHAR2(1000);
  v_JOB_NUM       NUMBER;
  v_APP_NM        VARCHAR2(100) := 'KITT';
  v_PROCEDURE_NM  VARCHAR2(100) := 'SP_NISC3_REFRESH';
  v_INPUT_PARMS   VARCHAR2(4000);
  v_STEP          VARCHAR2(100);
  p_PStatus       VARCHAR2(200);

  CURSOR DISABLE_CONSTRAINTS IS
    SELECT 'alter table KITT_NISC3.'||table_name||' disable constraint '||constraint_name
      FROM DBA_CONSTRAINTS
     WHERE OWNER='KITT_NISC3'
       and constraint_TYPE NOT IN ('P','U')
    ORDER BY TABLE_NAME; 
  DC              VARCHAR2(1000);
--  DC DBA_CONSTRAINTS%ROWTYPE;
   
  CURSOR TRUNCATE_TABLES IS
    SELECT 'TRUNCATE table KITT_NISC3.'||table_name
      FROM DBA_TABLES
     WHERE OWNER='KITT_NISC3'
       AND TABLE_NAME <> 'JOB_DETAIL'
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME; 
  TT              VARCHAR2(1000);
  
  CURSOR NOLOGGING IS
    select 'alter table KITT_NISC3.'||table_name||' nologging'
      from dba_tables
     where owner='KITT_NISC3'
       AND TABLE_NAME NOT IN ( 'JOB_DETAIL','P_USER_GUIDE')
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME;
  NL              VARCHAR2(1000);
 
  CURSOR INDEX_UNUSABLE IS
    select 'alter index KITT_NISC3.'||index_name||' unusable' 
      from dba_indexes
     where owner='KITT_NISC3'
       and UNIQUENESS<>'UNIQUE'
       AND INDEX_TYPE<>'LOB'
    ORDER BY index_NAME;
  IU              VARCHAR2(1000);
 
  CURSOR TRIGGER_DISABLE IS
    select 'alter TRIGGER KITT_NISC3.'||TRIGGER_name||' DISABLE'
      from dba_triggers
     where owner='KITT_NISC3'
    ORDER BY TRIGGER_NAME;
  TD              VARCHAR2(1000);
  
  CURSOR INSERT_ROWS IS
--    select 'insert /*+ APPEND */ into KITT_NISC3.'||table_name||' select * from KITT_NISC3.'||table_name||'@KITT_NISC3_KITTD'
--   select 'insert /*+ APPEND */ into KITT_NISC3.'||table_name||' select * from KITT_NISC3.'||table_name||'@KITT_NISC3_KITT_MIRROR'
   select 'insert /*+ APPEND */ into KITT_NISC3.'||table_name||' select * from KITT_NISC3.'||table_name||'@KITT_NISC3_PDWSHR'
     from USER_tables
    WHERE TABLE_NAME NOT IN ( 'JOB_DETAIL','P_USER_GUIDE')
      AND TEMPORARY = 'N'
    ORDER BY (NUM_ROWS*AVG_ROW_LEN) DESC;
  INS              VARCHAR2(1000);

  CURSOR INDEX_REBUILD IS
    select 'alter index KITT_NISC3.'||index_name||' REBUILD'
      from dba_indexes
     where owner='KITT_NISC3'
       and UNIQUENESS<>'UNIQUE'
       AND INDEX_TYPE<>'LOB'
    ORDER BY index_NAME;
  IR              VARCHAR2(1000);
  
  CURSOR LOGGING IS
    select 'alter table KITT_NISC3.'||table_name||' logging'
      from dba_tables
     where owner='KITT_NISC3'
       AND TABLE_NAME <> 'JOB_DETAIL'
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME;
  LOG             VARCHAR2(1000);
  
  CURSOR ENABLE_TRIGGER IS
    select 'alter TRIGGER KITT_NISC3.'||TRIGGER_name||' ENABLE'
      from dba_triggers
     where owner='KITT_NISC3'
    ORDER BY TRIGGER_NAME;
  ET             VARCHAR2(1000);
  
  CURSOR ENABLE_CONSTRAINT IS
    SELECT 'alter table KITT_NISC3.'||table_name||' enable constraint '||constraint_name
      FROM DBA_CONSTRAINTS
     WHERE OWNER='KITT_NISC3'
       and constraint_TYPE NOT IN ('P','U')
       and constraint_name <> 'SUB_TASK_SKIL__SUB_TASK__FK102'      -- ora-02298 parent key not found
    ORDER BY TABLE_NAME; 
  EC             VARCHAR2(1000);


BEGIN

  v_JOB_NUM := JOB_DETAIL_SEQ.NEXTVAL;
--  v_INPUT_PARMS := ' User Seq - '||p_USER_SEQ||' UserName - '||p_USERNAME||' Role - '||p_ROLE||' LOB - '||p_LOB||' SU - '||p_Service_Unit||' SA - '||p_Service_Area||' Org - '||p_Organization||' LastModBy - '||p_LAST_MODIFIED_BY;
  v_INPUT_PARMS := 'NONE';
  v_STEP := 'START';
  -- Input parms -  job_id, application_name, procedure_name, input_parms, step_descr, counter, comments, user_name
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,v_INPUT_PARMS,v_STEP,NULL,NULL,NULL);

  v_STEP    := 'DISABLE CONSTRAINTS';
  OPEN DISABLE_CONSTRAINTS;
    LOOP
      FETCH DISABLE_CONSTRAINTS
       INTO DC;
      EXIT WHEN DISABLE_CONSTRAINTS%NOTFOUND;
    
      EXECUTE IMMEDIATE DC;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'TRUNCATE_TABLES';
  OPEN TRUNCATE_TABLES;
    LOOP
      FETCH TRUNCATE_TABLES
       INTO TT;
      EXIT WHEN TRUNCATE_TABLES%NOTFOUND;
    
      EXECUTE IMMEDIATE TT;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'NOLOGGING';
  OPEN NOLOGGING;
    LOOP
      FETCH NOLOGGING
       INTO NL;
      EXIT WHEN NOLOGGING%NOTFOUND;
    
      EXECUTE IMMEDIATE NL;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'INDEX_UNUSABLE';
  OPEN INDEX_UNUSABLE;
    LOOP
      FETCH INDEX_UNUSABLE
       INTO IU;
      EXIT WHEN INDEX_UNUSABLE%NOTFOUND;
    
      EXECUTE IMMEDIATE IU;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'TRIGGER_DISABLE';
  OPEN TRIGGER_DISABLE;
    LOOP
      FETCH TRIGGER_DISABLE
       INTO TD;
      EXIT WHEN TRIGGER_DISABLE%NOTFOUND;
    
      EXECUTE IMMEDIATE TD;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'INSERT_ROWS';
  OPEN INSERT_ROWS;
    LOOP
      FETCH INSERT_ROWS
       INTO INS;
      EXIT WHEN INSERT_ROWS%NOTFOUND;
    
      EXECUTE IMMEDIATE INS;
      COMMIT;
      
      p_PStatus := INS ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'INDEX_REBUILD';
  OPEN INDEX_REBUILD;
    LOOP
      FETCH INDEX_REBUILD
       INTO IR;
      EXIT WHEN INDEX_REBUILD%NOTFOUND;
    
      EXECUTE IMMEDIATE IR;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'LOGGING';
  OPEN LOGGING;
    LOOP
      FETCH LOGGING
       INTO LOG;
      EXIT WHEN LOGGING%NOTFOUND;
    
      EXECUTE IMMEDIATE LOG;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'ENABLE_TRIGGER';
  OPEN ENABLE_TRIGGER;
    LOOP
      FETCH ENABLE_TRIGGER
       INTO ET;
      EXIT WHEN ENABLE_TRIGGER%NOTFOUND;
    
      EXECUTE IMMEDIATE ET;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

  v_STEP    := 'ENABLE_CONSTRAINT';
  OPEN ENABLE_CONSTRAINT;
    LOOP
      FETCH ENABLE_CONSTRAINT
       INTO EC;
      EXIT WHEN ENABLE_CONSTRAINT%NOTFOUND;
    
      EXECUTE IMMEDIATE EC;
        
    END LOOP;
    
    p_PStatus := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

    v_STEP    := 'RESET SEQUENCE';
    SP_NISC3_SEQUENCE_RESET(p_PSTATUS);
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);
--    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);

/*
  vSENDER   := 'jon.ctr.feld@faa.gov';
  vSENDER   := p_EMAIL;
  vRECEIVER := 'jon.ctr.feld@faa.gov';
  vSUBJECT  := 'Request for New User Account';
  
  SELECT ROLE_NAME
    INTO vROLE_NAME
    FROM SWB_USER_ROLES_LKUP
   WHERE ROLE_CD=p_ROLE;
    
  v_STEP := 'EMAIL';
     
  vMESSAGE  := 'A new account request has been received from '||p_USERNAME||' requesting the role of '||vROLE_NAME||' for the following organization(s):'||CHR(10)|| v_ACCESS_GROUPS ||CHR(10)||CHR(10)||'in Staffing Workbook. Please login to review and process the request.';
  vMESSAGE  := vMESSAGE||chr(10)||chr(10)||'You are receiving this email due to your role in Staffing Workbook as a User Administrator.  If you are receiving this email in error, please contact the Staffing Workbook System Administrator.';
 
  SP_MAILOUT_UTILITY(1, SENDER => vSENDER, RECIPIENT => vRECEIVER, CCRECIPIENT => NULL, SUBJECT => vSUBJECT, MESSAGE => vMESSAGE );
    
  p_PStatus := 'SUCCESS' ;
  
  v_STEP := 'COMPLETE';
    
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,NULL,p_LAST_MODIFIED_BY);
    
  RETURN;
*/
  
EXCEPTION
WHEN OTHERS THEN
  ROLLBACK;
  p_PStatus := 'Refresh error ' || SQLERRM ; 
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,p_PStatus,NULL);   
--  RETURN;

END SP_NISC3_REFRESH_20150627;
/
