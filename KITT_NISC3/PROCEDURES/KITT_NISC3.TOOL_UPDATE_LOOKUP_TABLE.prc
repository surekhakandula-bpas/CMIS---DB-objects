DROP PROCEDURE TOOL_UPDATE_LOOKUP_TABLE;

CREATE OR REPLACE PROCEDURE            TOOL_UPDATE_LOOKUP_TABLE IS

/******************************************************************************
   NAME:       TOOL_UPDATE_LOOKUP_TABLE
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/20/2009    Chao Yu      1. Created this procedure.

   NOTES:

 
******************************************************************************/
Curr_DB  varchar2(10);
ctn number;

BEGIN

  null;
   /*
    EXECUTE IMMEDIATE 'create table STATE_BK as select * from STATE';
    EXECUTE IMMEDIATE 'create table STATUS_BK as select * from STATUS';
    EXECUTE IMMEDIATE 'create table OWNERSHIP_BK as select * from OWNERSHIP';
    EXECUTE IMMEDIATE 'create table SYSTEM_ROLE_BK as select * from SYSTEM_ROLE';
  
   
    
    if GET_ENV_NAME = 'NISC3_TEST' then
    

        for c in (select N_STATE_NUMBER,C_STATE_LABEL,T_COMMENTS from STATE@KITT_DEV.REGRESS.RDBMS.DEV.US.ORACLE.COM) ) loop
        
          
            select count(*) into ctn
             from STATE
            where N_STATE_NUMBER =c.N_STATE_NUMBER;
            
            if ctn = 0 then
            
               
               insert into state (N_STATE_NUMBER,C_STATE_LABEL,T_COMMENTS)
               values ( c.N_STATE_NUMBER,c.C_STATE_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update state
                set C_STATE_LABEL=c.C_STATE_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_STATE_NUMBER =c.N_STATE_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
        dbms_output.put_line('state');
        
         for c in (select N_STATUS_NUMBER,C_STATUS_LABEL,T_COMMENTS from STATUS@KITT_DEV.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from STATUS
            where N_STATUS_NUMBER =c.N_STATUS_NUMBER;
            
            if ctn = 0 then
            
               
               insert into STATUS (N_STATUS_NUMBER,C_STATUS_LABEL,T_COMMENTS)
               values ( c.N_STATUS_NUMBER,c.C_STATUS_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update STATUS
                set C_STATUS_LABEL=c.C_STATUS_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_STATUS_NUMBER =c.N_STATUS_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
        dbms_output.put_line('STATUS');
        
           for c in (select N_OWNERSHIP_NUMBER,C_OWNERSHIP_LABEL,T_COMMENTS from OWNERSHIP@KITT_DEV.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from OWNERSHIP
            where N_OWNERSHIP_NUMBER =c.N_OWNERSHIP_NUMBER;
            
            if ctn = 0 then
            
               
               insert into OWNERSHIP (N_OWNERSHIP_NUMBER,C_OWNERSHIP_LABEL,T_COMMENTS)
               values ( c.N_OWNERSHIP_NUMBER,c.C_OWNERSHIP_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update OWNERSHIP
                set C_OWNERSHIP_LABEL=c.C_OWNERSHIP_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_OWNERSHIP_NUMBER =c.N_OWNERSHIP_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
         dbms_output.put_line('OWNERSHIP');
     
           for c in (select N_ROLE_NUMBER,C_ROLE_LABEL,C_ROLE_DESCRIPTION,C_EMPLOYEE_ROLE from SYSTEM_ROLE@KITT_DEV.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from SYSTEM_ROLE
            where N_ROLE_NUMBER =c.N_ROLE_NUMBER;
            
            if ctn = 0 then
            
               
               insert into SYSTEM_ROLE (N_ROLE_NUMBER,C_ROLE_LABEL,C_ROLE_DESCRIPTION,C_EMPLOYEE_ROLE)
               values ( c.N_ROLE_NUMBER,c.C_ROLE_LABEL,c.C_ROLE_DESCRIPTION,c.C_EMPLOYEE_ROLE);
               commit;
            
            
            else
              
              update SYSTEM_ROLE
                set C_ROLE_LABEL=c.C_ROLE_LABEL,
                    C_ROLE_DESCRIPTION =c.C_ROLE_DESCRIPTION,
                    C_EMPLOYEE_ROLE =c.C_EMPLOYEE_ROLE
              where N_ROLE_NUMBER =c.N_ROLE_NUMBER;
              commit;
                 
            
            end if;
        
        end loop; 
        
    end if;
   
  dbms_output.put_line('SYSTEM_ROLE');
 
   
   if GET_ENV_NAME = 'NISC3_BETA then 
    
        for c in (select N_STATE_NUMBER,C_STATE_LABEL,T_COMMENTS 
                  from STATE@KITT_TEST.REGRESS.RDBMS.DEV.US.ORACLE.COM) loop
        
          
            select count(*) into ctn
             from STATE
            where N_STATE_NUMBER =c.N_STATE_NUMBER;
            
            if ctn = 0 then
            
               
               insert into state (N_STATE_NUMBER,C_STATE_LABEL,T_COMMENTS)
               values ( c.N_STATE_NUMBER,c.C_STATE_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update state
                set C_STATE_LABEL=c.C_STATE_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_STATE_NUMBER =c.N_STATE_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        dbms_output.put_line('state');
        
         for c in (select N_STATUS_NUMBER,C_STATUS_LABEL,T_COMMENTS 
                     from STATUS@KITT_TEST.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from STATUS
            where N_STATUS_NUMBER =c.N_STATUS_NUMBER;
            
            if ctn = 0 then
            
               
               insert into STATUS (N_STATUS_NUMBER,C_STATUS_LABEL,T_COMMENTS)
               values ( c.N_STATUS_NUMBER,c.C_STATUS_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update STATUS
                set C_STATUS_LABEL=c.C_STATUS_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_STATUS_NUMBER =c.N_STATUS_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
         dbms_output.put_line('STATUS');
         
           for c in (select N_OWNERSHIP_NUMBER,C_OWNERSHIP_LABEL,T_COMMENTS 
                        from OWNERSHIP@KITT_TEST.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from OWNERSHIP
            where N_OWNERSHIP_NUMBER =c.N_OWNERSHIP_NUMBER;
            
            if ctn = 0 then
            
               
               insert into OWNERSHIP (N_OWNERSHIP_NUMBER,C_OWNERSHIP_LABEL,T_COMMENTS)
               values ( c.N_OWNERSHIP_NUMBER,c.C_OWNERSHIP_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update OWNERSHIP
                set C_OWNERSHIP_LABEL=c.C_OWNERSHIP_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_OWNERSHIP_NUMBER =c.N_OWNERSHIP_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
         dbms_output.put_line('OWNERSHIP');
     
           for c in (select N_ROLE_NUMBER,C_ROLE_LABEL,C_ROLE_DESCRIPTION,C_EMPLOYEE_ROLE 
                       from SYSTEM_ROLE@KITT_TEST.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from SYSTEM_ROLE
            where N_ROLE_NUMBER =c.N_ROLE_NUMBER;
            
            if ctn = 0 then
            
               
               insert into SYSTEM_ROLE (N_ROLE_NUMBER,C_ROLE_LABEL,C_ROLE_DESCRIPTION,C_EMPLOYEE_ROLE)
               values ( c.N_ROLE_NUMBER,c.C_ROLE_LABEL,c.C_ROLE_DESCRIPTION,c.C_EMPLOYEE_ROLE);
               commit;
            
            
            else
              
              update SYSTEM_ROLE
                set C_ROLE_LABEL=c.C_ROLE_LABEL,
                    C_ROLE_DESCRIPTION =c.C_ROLE_DESCRIPTION,
                    C_EMPLOYEE_ROLE =c.C_EMPLOYEE_ROLE
              where N_ROLE_NUMBER =c.N_ROLE_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
         dbms_output.put_line('SYSTEM_ROLE');
        
    end if;
    
   
     if GET_ENV_NAME = 'NISC3_BETA then 
    
        for c in (select N_STATE_NUMBER,C_STATE_LABEL,T_COMMENTS 
                  from STATE@KITT_BETA.REGRESS.RDBMS.DEV.US.ORACLE.COM) loop
        
          
            select count(*) into ctn
             from STATE
            where N_STATE_NUMBER =c.N_STATE_NUMBER;
            
            if ctn = 0 then
            
               
               insert into state (N_STATE_NUMBER,C_STATE_LABEL,T_COMMENTS)
               values ( c.N_STATE_NUMBER,c.C_STATE_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update state
                set C_STATE_LABEL=c.C_STATE_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_STATE_NUMBER =c.N_STATE_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        dbms_output.put_line('state');
        
         for c in (select N_STATUS_NUMBER,C_STATUS_LABEL,T_COMMENTS 
                     from STATUS@KITT_BETA.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from STATUS
            where N_STATUS_NUMBER =c.N_STATUS_NUMBER;
            
            if ctn = 0 then
            
               
               insert into STATUS (N_STATUS_NUMBER,C_STATUS_LABEL,T_COMMENTS)
               values ( c.N_STATUS_NUMBER,c.C_STATUS_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update STATUS
                set C_STATUS_LABEL=c.C_STATUS_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_STATUS_NUMBER =c.N_STATUS_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
         dbms_output.put_line('STATUS');
         
           for c in (select N_OWNERSHIP_NUMBER,C_OWNERSHIP_LABEL,T_COMMENTS 
                        from OWNERSHIP@KITT_BETA.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from OWNERSHIP
            where N_OWNERSHIP_NUMBER =c.N_OWNERSHIP_NUMBER;
            
            if ctn = 0 then
            
               
               insert into OWNERSHIP (N_OWNERSHIP_NUMBER,C_OWNERSHIP_LABEL,T_COMMENTS)
               values ( c.N_OWNERSHIP_NUMBER,c.C_OWNERSHIP_LABEL,c.T_COMMENTS);
               commit;
            
            
            else
              
              update OWNERSHIP
                set C_OWNERSHIP_LABEL=c.C_OWNERSHIP_LABEL,
                    T_COMMENTS =c.T_COMMENTS
              where N_OWNERSHIP_NUMBER =c.N_OWNERSHIP_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
         dbms_output.put_line('OWNERSHIP');
     
           for c in (select N_ROLE_NUMBER,C_ROLE_LABEL,C_ROLE_DESCRIPTION,C_EMPLOYEE_ROLE 
                       from SYSTEM_ROLE@KITT_BETA.REGRESS.RDBMS.DEV.US.ORACLE.COM ) loop
        
          
            select count(*) into ctn
             from SYSTEM_ROLE
            where N_ROLE_NUMBER =c.N_ROLE_NUMBER;
            
            if ctn = 0 then
            
               
               insert into SYSTEM_ROLE (N_ROLE_NUMBER,C_ROLE_LABEL,C_ROLE_DESCRIPTION,C_EMPLOYEE_ROLE)
               values ( c.N_ROLE_NUMBER,c.C_ROLE_LABEL,c.C_ROLE_DESCRIPTION,c.C_EMPLOYEE_ROLE);
               commit;
            
            
            else
              
              update SYSTEM_ROLE
                set C_ROLE_LABEL=c.C_ROLE_LABEL,
                    C_ROLE_DESCRIPTION =c.C_ROLE_DESCRIPTION,
                    C_EMPLOYEE_ROLE =c.C_EMPLOYEE_ROLE
              where N_ROLE_NUMBER =c.N_ROLE_NUMBER;
              commit;
                 
            
            end if;
        
        end loop;
        
         dbms_output.put_line('SYSTEM_ROLE');
        
    end if;

   
   */

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
      dbms_output.put_line('Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.');
END TOOL_UPDATE_LOOKUP_TABLE; 
/
