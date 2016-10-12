DROP PROCEDURE SP_KFDBUSER_REFRESH;

CREATE OR REPLACE PROCEDURE               SP_KFDBUSER_REFRESH
--(
--                        v_STATUS          OUT VARCHAR2 )  
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
  v_PROCEDURE_NM  VARCHAR2(100) := 'SP_KFDBUSER_REFRESH';
  v_INPUT_PARMS   VARCHAR2(4000);
  v_STEP          VARCHAR2(100);
  v_STATUS        VARCHAR2(200);

  CURSOR DISABLE_CONSTRAINTS IS
    SELECT 'alter table KITT_KFDBUSER.'||table_name||' disable constraint '||constraint_name
      FROM USER_CONSTRAINTS
     WHERE constraint_TYPE NOT IN ('P','U')
    ORDER BY TABLE_NAME; 
  DC              VARCHAR2(1000);
--  DC USER_CONSTRAINTS%ROWTYPE;
   
  CURSOR TRUNCATE_TABLES IS
    SELECT 'TRUNCATE table KITT_KFDBUSER.'||table_name
      FROM USER_TABLES
    ORDER BY TABLE_NAME; 
  TT              VARCHAR2(1000);
   
  CURSOR NOLOGGING IS
    select 'alter table KITT_KFDBUSER.'||table_name||' nologging'
      from USER_tables
    ORDER BY TABLE_NAME;
  NL              VARCHAR2(1000);
 
  CURSOR INDEX_UNUSABLE IS
    select 'alter index KITT_KFDBUSER.'||index_name||' unusable' 
      from USER_indexes
     where UNIQUENESS<>'UNIQUE'
       AND INDEX_TYPE<>'LOB'
    ORDER BY index_NAME;
  IU              VARCHAR2(1000);
 
  CURSOR TRIGGER_DISABLE IS
    select 'alter TRIGGER KITT_KFDBUSER.'||TRIGGER_name||' DISABLE'
      from USER_triggers
    ORDER BY TRIGGER_NAME;
  TD              VARCHAR2(1000);
  
  CURSOR INSERT_ROWS IS
    select 'insert /*+ APPEND */ into KITT_KFDBUSER.'||table_name||' select * from KITT_KFDBUSER.'||table_name||'@KITT_KFDBUSER_KITTD'
      from USER_tables
    ORDER BY TABLE_NAME;
--    ORDER BY (NUM_ROWS*AVG_ROW_LEN) DESC;
  INS              VARCHAR2(1000);

  CURSOR INDEX_REBUILD IS
    select 'alter index KITT_KFDBUSER.'||index_name||' REBUILD'
      from USER_indexes
     where UNIQUENESS<>'UNIQUE'
       AND INDEX_TYPE<>'LOB'
    ORDER BY index_NAME;
  IR              VARCHAR2(1000);
  
  CURSOR LOGGING IS
    select 'alter table KITT_KFDBUSER.'||table_name||' logging'
      from USER_tables
    ORDER BY TABLE_NAME;
  LOG             VARCHAR2(1000);
  
  CURSOR ENABLE_TRIGGER IS
    select 'alter TRIGGER KITT_KFDBUSER.'||TRIGGER_name||' ENABLE'
      from USER_triggers
    ORDER BY TRIGGER_NAME;
  ET             VARCHAR2(1000);
  
  CURSOR ENABLE_CONSTRAINT IS
    SELECT 'alter table KITT_KFDBUSER.'||table_name||' enable constraint '||constraint_name
      FROM USER_CONSTRAINTS
     WHERE constraint_TYPE NOT IN ('P','U')
    ORDER BY TABLE_NAME; 
  EC             VARCHAR2(1000);


BEGIN

  v_JOB_NUM := KITT_NISC3.JOB_DETAIL_SEQ.NEXTVAL;
--  v_INPUT_PARMS := ' User Seq - '||p_USER_SEQ||' UserName - '||p_USERNAME||' Role - '||p_ROLE||' LOB - '||p_LOB||' SU - '||p_Service_Unit||' SA - '||p_Service_Area||' Org - '||p_Organization||' LastModBy - '||p_LAST_MODIFIED_BY;
  v_INPUT_PARMS := 'NONE';
  v_STEP := 'START';
  -- Input parms -  job_id, application_name, procedure_name, input_parms, step_descr, counter, comments, user_name
  KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,v_INPUT_PARMS,v_STEP,NULL,NULL,NULL);

  v_STEP    := 'DISABLE CONSTRAINTS';
  OPEN DISABLE_CONSTRAINTS;
    LOOP
      FETCH DISABLE_CONSTRAINTS
       INTO DC;
      EXIT WHEN DISABLE_CONSTRAINTS%NOTFOUND;
    
      EXECUTE IMMEDIATE DC;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
  
  v_STEP    := 'TRUNCATE_TABLES';
  OPEN TRUNCATE_TABLES;
    LOOP
      FETCH TRUNCATE_TABLES
       INTO TT;
      EXIT WHEN TRUNCATE_TABLES%NOTFOUND;
    
      EXECUTE IMMEDIATE TT;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
  
  v_STEP    := 'NOLOGGING';
  OPEN NOLOGGING;
    LOOP
      FETCH NOLOGGING
       INTO NL;
      EXIT WHEN NOLOGGING%NOTFOUND;
    
      EXECUTE IMMEDIATE NL;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);


  v_STEP    := 'INDEX_UNUSABLE';
  OPEN INDEX_UNUSABLE;
    LOOP
      FETCH INDEX_UNUSABLE
       INTO IU;
      EXIT WHEN INDEX_UNUSABLE%NOTFOUND;
    
      EXECUTE IMMEDIATE IU;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
  
  v_STEP    := 'TRIGGER_DISABLE';
  OPEN TRIGGER_DISABLE;
    LOOP
      FETCH TRIGGER_DISABLE
       INTO TD;
      EXIT WHEN TRIGGER_DISABLE%NOTFOUND;
    
      EXECUTE IMMEDIATE TD;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);


  v_STEP    := 'INSERT_ROWS';
  OPEN INSERT_ROWS;
    LOOP
      FETCH INSERT_ROWS
       INTO INS;
      EXIT WHEN INSERT_ROWS%NOTFOUND;
    
      EXECUTE IMMEDIATE INS;
      COMMIT;
      
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,INS,NULL);
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

 
  v_STEP    := 'INDEX_REBUILD';
  OPEN INDEX_REBUILD;
    LOOP
      FETCH INDEX_REBUILD
       INTO IR;
      EXIT WHEN INDEX_REBUILD%NOTFOUND;
    
      EXECUTE IMMEDIATE IR;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'LOGGING';
  OPEN LOGGING;
    LOOP
      FETCH LOGGING
       INTO LOG;
      EXIT WHEN LOGGING%NOTFOUND;
    
      EXECUTE IMMEDIATE LOG;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

    v_STEP    := 'ENABLE_TRIGGER';
    OPEN ENABLE_TRIGGER;
    LOOP
      FETCH ENABLE_TRIGGER
       INTO ET;
      EXIT WHEN ENABLE_TRIGGER%NOTFOUND;
    
      EXECUTE IMMEDIATE ET;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);


  v_STEP    := 'ENABLE_CONSTRAINT';
  OPEN ENABLE_CONSTRAINT;
    LOOP
      FETCH ENABLE_CONSTRAINT
       INTO EC;
      EXIT WHEN ENABLE_CONSTRAINT%NOTFOUND;
    
      EXECUTE IMMEDIATE EC;
        
    END LOOP;
    
    v_STATUS := 'SUCCESS' ;
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

    v_STEP    := 'RESET SEQUENCE';
    SP_KFDBUSER_SEQUENCE_RESET(v_STATUS);
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
    
    v_STEP    := 'RECOMPILE';
    DBMS_UTILITY.compile_schema(schema => 'KITT_KFDBUSER');
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,V_Status,NULL);

    v_STEP    := 'MAIL';
    KITT_NISC3.SP_MAILOUT_UTILITY(NULL,'jon.ctr.feld@faa.gov','jon.ctr.feld@faa.gov',NULL,'CMIS KFDBUSER REFRESH COMPLETE','KITT_KFDBUSER refresh is complete.');
    KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);
    
 
EXCEPTION
WHEN OTHERS THEN
  ROLLBACK;
  v_STATUS := 'Refresh error ' || SQLERRM ; 
  KITT_NISC3.SP_MAILOUT_UTILITY(NULL,'jon.ctr.feld@faa.gov','jon.ctr.feld@faa.gov',NULL,'CMIS KFDBUSER REFRESH FAILED',v_STATUS);
  KITT_NISC3.SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);   
--  RETURN;

END SP_KFDBUSER_REFRESH;
/

GRANT EXECUTE ON SP_KFDBUSER_REFRESH TO SNAMBIAR;
