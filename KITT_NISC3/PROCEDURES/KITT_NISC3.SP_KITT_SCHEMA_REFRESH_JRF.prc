DROP PROCEDURE SP_KITT_SCHEMA_REFRESH_JRF;

CREATE OR REPLACE PROCEDURE            SP_KITT_SCHEMA_REFRESH_jrf
(
    p_DATABASE        IN  VARCHAR2
   ,p_SCHEMA          IN  VARCHAR2
   ,p_STATUS          OUT VARCHAR2 
)  
/*
---------------------------------------------------------------------------------------------------
  Object Name:  SP_KITT_SCHEMA_REFRESH
  Author:       J Feld
  Date Created: 06/30/2015    
  Purpose: Refresh from production KITTD
  
  Modification History:
---------------------------------------------------------------------------------------------------  
*/                              
IS
  vSENDER         VARCHAR2(200);
  vRECEIVER       VARCHAR2(200);
  vSUBJECT        VARCHAR2(200);
  vMESSAGE        VARCHAR2(32000); 
  vEMAIL          VARCHAR2(1000);
  v_JOB_NUM       NUMBER;
  v_APP_NM        VARCHAR2(100) := 'KITT';
  v_PROCEDURE_NM  VARCHAR2(100) := 'SP_KITT_SCHEMA_REFRESH';
  v_INPUT_PARMS   VARCHAR2(4000);
  v_STEP          VARCHAR2(100);
  v_STATUS        VARCHAR2(200);
  v_DB_LINK       VARCHAR2(100);

  CURSOR INSERT_ROWS IS
   select 'insert /*+ APPEND */ into '||p_SCHEMA||'.'||table_name||'@'||v_DB_LINK||' select * from '||p_SCHEMA||'.'||table_name||';'
       from dba_tables
     where owner=UPPER(p_SCHEMA)
       AND TABLE_NAME NOT IN ('JOB_DETAIL','P_USER_GUIDE')
       AND TEMPORARY = 'N'
    ORDER BY TABLE_NAME;
  INS              VARCHAR2(1000);

BEGIN

  v_JOB_NUM := JOB_DETAIL_SEQ.NEXTVAL;
  v_INPUT_PARMS := ' DB: '||p_DATABASE||' SCHEMA: '||p_SCHEMA;
  v_STEP := 'START';
  -- Input parms -  job_id, application_name, procedure_name, input_parms, step_descr, counter, comments, user_name
  SP_JOBDETAIL@KITT_NISC3(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,v_INPUT_PARMS,v_STEP,NULL,NULL,NULL);

  CASE 
    WHEN UPPER(p_DATABASE) = 'KITTM'
     AND UPPER(p_SCHEMA)   = 'KITT_NISC3'
    THEN v_DB_LINK         = 'KITT_NISC3_KITTM';
    WHEN UPPER(p_DATABASE) = 'KITTM'
     AND UPPER(p_SCHEMA)   = 'KITT_KFDBUSER'
    THEN v_DB_LINK         = 'KITT_KFDBUSER_KITTM';
    WHEN UPPER(p_DATABASE) = 'KITTDEV'
     AND UPPER(p_SCHEMA)   = 'KITT_NISC3'
    THEN v_DB_LINK         = 'KITT_NISC3_KITTDEV';
    WHEN UPPER(p_DATABASE) = 'KITTM'
     AND UPPER(p_SCHEMA)   = 'KITT_KFDBUSER'
    THEN v_DB_LINK         = 'KITT_KFDBUSER_KITTDEV';
  END CASE;

  v_STEP    := 'SP_KITT_DATA_REFRESH DISABLE';
  SP_KITT_DATA_REFRESH@v_DB_LINK(v_JOB_NUM,UPPER(p_SCHEMA),'DISABLE',v_STATUS);
/*
  v_STEP    := 'INSERT_ROWS';
  OPEN INSERT_ROWS;
    LOOP
      FETCH INSERT_ROWS
       INTO INS;
      EXIT WHEN INSERT_ROWS%NOTFOUND;
    
      EXECUTE IMMEDIATE INS;
      COMMIT;
      
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL@KITT_NISC3(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,INS,NULL); 
       
    END LOOP;
*/    
    v_STATUS := 'SUCCESS' ;
    SP_JOBDETAIL@KITT_NISC3(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);

  v_STEP    := 'SP_KITT_DATA_REFRESH ENABLE';
  SP_KITT_DATA_REFRESH@v_DB_LINK(v_JOB_NUM,UPPER(p_SCHEMA),'ENABLE',v_STATUS);

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
    
  v_STATUS := 'SUCCESS' ;
  
  v_STEP := 'COMPLETE';
    
  SP_JOBDETAIL(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,NULL,p_LAST_MODIFIED_BY);
    
  RETURN;
*/
  
EXCEPTION
WHEN OTHERS THEN
  ROLLBACK;
  v_STATUS := 'Refresh error ' || SQLERRM ; 
  SP_JOBDETAIL@KITT_NISC3(v_JOB_NUM,v_APP_NM,v_PROCEDURE_NM,NULL,v_STEP,NULL,v_STATUS,NULL);   

END SP_KITT_SCHEMA_REFRESH_jrf;
/
