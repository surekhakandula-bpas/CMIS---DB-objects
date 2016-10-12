DROP PROCEDURE SP_NISC3_REFRESH;

CREATE OR REPLACE PROCEDURE            SP_NISC3_REFRESH
--(
--                        p_PSTATUS          OUT VARCHAR2 )  
/*
---------------------------------------------------------------------------------------------------
  Object Name:  SP_NISC3_REFRESH
  Author:       J Feld
  Date Created: 06/15/2015    
  Purpose: Refresh Prod Mirror from production KITTD
  
  Modification History:
  20150827  J Feld  Removed KITT_LOG from refresh.  Causes dup record error if user is connected during refresh
  20160106  J Feld  Added email notification when procedure complete
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
  v_STATUS       VARCHAR2(200);

  CURSOR DISABLE_CONSTRAINTS IS
    SELECT 'alter table KITT_NISC3.'||table_name||' disable constraint '||constraint_name
      FROM USER_CONSTRAINTS
     WHERE constraint_TYPE NOT IN ('P','U')
       and table_name not like 'BIN%'
    ORDER BY TABLE_NAME; 
  DC              VARCHAR2(1000);
--  DC USER_CONSTRAINTS%ROWTYPE;
   
  CURSOR TRUNCATE_TABLES IS
    SELECT 'TRUNCATE table KITT_NISC3.'||table_name
      FROM USER_TABLES@KITT_NISC3_KITTD
     WHERE TABLE_NAME NOT IN ('JOB_DETAIL','P_USER_GUIDE','KITT_LOG')
       and table_name not like 'BIN%'
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME; 
  TT              VARCHAR2(1000);
 
  CURSOR NOLOGGING IS
    select 'alter table KITT_NISC3.'||table_name||' nologging'
      from USER_tables
     where TABLE_NAME NOT IN ('JOB_DETAIL','P_USER_GUIDE','KITT_LOG')
       and table_name not like 'BIN%'
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME;
  NL              VARCHAR2(1000);
  
    CURSOR NOLOGGING_IDX IS
    select 'alter index KITT_NISC3.'||index_name||' nologging'
      from USER_indexes
     where table_name not like 'BIN%'
       AND INDEX_TYPE<>'LOB'
    ORDER BY INDEX_NAME;
  NLI             VARCHAR2(1000);
  
  CURSOR INDEX_UNUSABLE IS
    select 'alter index KITT_NISC3.'||index_name||' unusable' 
      from USER_indexes
     where table_name not like 'BIN%'
       and UNIQUENESS<>'UNIQUE'
       AND INDEX_TYPE<>'LOB'
    ORDER BY INDEX_NAME;
  IU              VARCHAR2(1000);
  
  CURSOR BLOB_NOLOG IS
    select 'alter TABLE KITT_NISC3.'||table_name||' modify lob('||column_name||') (nocache nologging)'
      from user_lobs
     where table_name not like 'BIN%'
    ORDER BY table_name;
  bnlg            VARCHAR2(1000);
  
 --alter table KITT_NISC3.USER_GUIDE modify lob(b_document) (nocache nologging);
 
  CURSOR TRIGGER_DISABLE IS
    select 'alter TRIGGER KITT_NISC3.'||TRIGGER_name||' DISABLE'
      from USER_triggers
     where table_name not like 'BIN%'
    ORDER BY TRIGGER_NAME;
  TD              VARCHAR2(1000);
  
  CURSOR INSERT_ROWS IS
--    select 'insert /*+ APPEND */ into KITT_NISC3.'||table_name||' select * from KITT_NISC3.'||table_name||'@KITT_NISC3_KITTD'
--   select 'insert /*+ APPEND */ into KITT_NISC3.'||table_name||' select * from KITT_NISC3.'||table_name||'@KITT_NISC3_KITT_MIRROR'
   select 'insert /*+ APPEND */ into KITT_NISC3.'||table_name||' select * from KITT_NISC3.'||table_name||'@KITT_NISC3_KITTD'
       from USER_tables@KITT_NISC3_KITTD
     where TABLE_NAME NOT IN ('JOB_DETAIL','P_USER_GUIDE','REPORT_FILTER_VALUES','KITT_LOG')
       and table_name not like 'BIN%'
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME;
--    ORDER BY (NUM_ROWS*AVG_ROW_LEN) DESC;
  INS              VARCHAR2(1000);

  CURSOR INDEX_REBUILD IS
    select 'alter index KITT_NISC3.'||index_name||' REBUILD'
      from USER_indexes
     where table_name not like 'BIN%'
       and UNIQUENESS<>'UNIQUE'
       AND INDEX_TYPE<>'LOB'
    ORDER BY index_NAME;
  IR              VARCHAR2(1000);
 
  CURSOR LOGGING IS
    select 'alter table KITT_NISC3.'||table_name||' logging'
      from USER_tables
     where TABLE_NAME NOT IN ('JOB_DETAIL','P_USER_GUIDE','KITT_LOG')
       and table_name not like 'BIN%'
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME;
  LOG             VARCHAR2(1000);
 
  CURSOR BLOB_LOG IS
    select 'alter TABLE KITT_NISC3.'||table_name||' modify lob('||column_name||') (cache logging)'
      from user_lobs
     where table_name not like 'BIN%'
    ORDER BY table_name;
  blg             VARCHAR2(1000);
   
    CURSOR LOGGING_IDX IS
    select 'alter index KITT_NISC3.'||index_name||' logging'
      from USER_indexes
     where table_name not like 'BIN%'
       AND INDEX_TYPE<>'LOB'
    ORDER BY INDEX_NAME;
  LOGI            VARCHAR2(1000);
  
  CURSOR ENABLE_TRIGGER IS
    select 'alter TRIGGER KITT_NISC3.'||TRIGGER_name||' ENABLE'
      from USER_triggers
     where table_name not like 'BIN%'
    ORDER BY TRIGGER_NAME;
  ET             VARCHAR2(1000);
  
  CURSOR ENABLE_CONSTRAINT IS
    SELECT 'alter table KITT_NISC3.'||table_name||' enable constraint '||constraint_name
      FROM USER_CONSTRAINTS
     WHERE table_name not like 'BIN%'
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
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'TRUNCATE_TABLES';
  OPEN TRUNCATE_TABLES;
    LOOP
      FETCH TRUNCATE_TABLES
       INTO TT;
      EXIT WHEN TRUNCATE_TABLES%NOTFOUND;
    
      EXECUTE IMMEDIATE TT;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'NOLOGGING';
  OPEN NOLOGGING;
    LOOP
      FETCH NOLOGGING
       INTO NL;
      EXIT WHEN NOLOGGING%NOTFOUND;
    
      EXECUTE IMMEDIATE NL;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'BLOB NOLOGGING';
  OPEN BLOB_NOLOG;
    LOOP
      FETCH BLOB_NOLOG
       INTO BNLG;
      EXIT WHEN BLOB_NOLOG%NOTFOUND;
    
      EXECUTE IMMEDIATE BNLG;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'NOLOGGING IDX';
  OPEN NOLOGGING_IDX;
    LOOP
      FETCH NOLOGGING_IDX
       INTO NLI;
      EXIT WHEN NOLOGGING_IDX%NOTFOUND;
    
      EXECUTE IMMEDIATE NLI;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
    
  v_STEP    := 'INDEX_UNUSABLE';
  OPEN INDEX_UNUSABLE;
    LOOP
      FETCH INDEX_UNUSABLE
       INTO IU;
      EXIT WHEN INDEX_UNUSABLE%NOTFOUND;
    
      EXECUTE IMMEDIATE IU;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'TRIGGER_DISABLE';
  OPEN TRIGGER_DISABLE;
    LOOP
      FETCH TRIGGER_DISABLE
       INTO TD;
      EXIT WHEN TRIGGER_DISABLE%NOTFOUND;
    
      EXECUTE IMMEDIATE TD;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'INSERT_ROWS';
  OPEN INSERT_ROWS;
    LOOP
      FETCH INSERT_ROWS
       INTO INS;
      EXIT WHEN INSERT_ROWS%NOTFOUND;
    
      EXECUTE IMMEDIATE INS;
      COMMIT;
      
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,INS,NULL); 
       
    END LOOP;
  
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'INDEX_REBUILD';
  OPEN INDEX_REBUILD;
    LOOP
      FETCH INDEX_REBUILD
       INTO IR;
      EXIT WHEN INDEX_REBUILD%NOTFOUND;
    
      EXECUTE IMMEDIATE IR;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'LOGGING';
  OPEN LOGGING;
    LOOP
      FETCH LOGGING
       INTO LOG;
      EXIT WHEN LOGGING%NOTFOUND;
    
      EXECUTE IMMEDIATE LOG;
        
    END LOOP;
    
  v_STATUS := 'SUCCESS' ;
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'BLOB LOGGING';
  OPEN BLOB_LOG;
    LOOP
      FETCH BLOB_LOG
       INTO BLG;
      EXIT WHEN BLOB_LOG%NOTFOUND;
    
      EXECUTE IMMEDIATE BLG;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'IDX LOGGING';
 
  OPEN LOGGING_IDX;
    LOOP
      FETCH LOGGING_IDX
       INTO LOGI;
      EXIT WHEN LOGGING_IDX%NOTFOUND;
    
      EXECUTE IMMEDIATE LOGI;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
 
  v_STEP    := 'ENABLE_TRIGGER';
  OPEN ENABLE_TRIGGER;
    LOOP
      FETCH ENABLE_TRIGGER
       INTO ET;
      EXIT WHEN ENABLE_TRIGGER%NOTFOUND;
    
      EXECUTE IMMEDIATE ET;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'ENABLE_CONSTRAINT';
  OPEN ENABLE_CONSTRAINT;
    LOOP
      FETCH ENABLE_CONSTRAINT
       INTO EC;
      EXIT WHEN ENABLE_CONSTRAINT%NOTFOUND;
    
      EXECUTE IMMEDIATE EC;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

    v_STEP    := 'RESET SEQUENCE';
    SP_NISC3_SEQUENCE_RESET(v_STATUS);
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

    v_STEP    := 'MAIL';
    SP_MAILOUT_UTILITY(NULL,'jon.ctr.feld@faa.gov','jon.ctr.feld@faa.gov',NULL,'CMIS NISC3 REFRESH COMPLETE','KITT_NISC3 refresh is complete.');
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

    v_STEP    := 'RECOMPILE';
    DBMS_UTILITY.compile_schema(schema => 'KITT_NISC3');
    SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
  
EXCEPTION
WHEN OTHERS THEN
  ROLLBACK;
  v_STATUS := 'Refresh error ' || SQLERRM ; 
  SP_MAILOUT_UTILITY(NULL,'jon.ctr.feld@faa.gov','jon.ctr.feld@faa.gov',NULL,'CMIS NISC3 REFRESH FAILED',v_STATUS);
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);   
--  RETURN;

END SP_NISC3_REFRESH;
/

