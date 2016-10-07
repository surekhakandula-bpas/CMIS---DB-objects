DROP PROCEDURE P_PRISM_STATUS_TRACK;

CREATE OR REPLACE PROCEDURE               p_prism_status_track(P_PR VARCHAR2, P_CONTRACT_NUM VARCHAR2,P_USER VARCHAR2, pr_found_flag OUT VARCHAR2)
 IS
--tmpVar NUMBER;
/******************************************************************************
   NAME:       prism_status_track
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/8/2012          1. Created this function.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     prism_pr_status_track
      Sysdate:         2/8/2012
      Date and Time:   2/8/2012, 10:52:41 AM, and 2/8/2012 10:52:41 AM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

--******************************************************************************/
v_pr_found VARCHAR2(30);
v_min_secs number;
V_counter number:=0;
v_jobno number;
os_err varchar2(200);
v_pr varchar2(30):=upper(p_pr);
--v_contract_num varchar2(30):= upper(p_contract_num);
v_contract_num varchar2(30):= 'DTFAWA-11-C-00003';
BEGIN
  -- capture the log info
  update pr_image_log 
  set pl_sql_entry_ts = sysdate
  where pr = v_pr;
  -- calling package
  prism_pr_status_track.P_populate_pr_request_data(v_pr , v_contract_num , p_user, os_err) ;
  --sys.dbms_lock.sleep(1);
    
 loop
   v_counter:=v_counter+1;
   --dbms_output.put_line('after the loop');
   --sys.dbms_lock.sleep(1);
   select NVL(pr_found,'null') into v_pr_found
   from kitt_pr_request
   where pr = v_PR;
      --dbms_output.put_line (v_counter);
      --dbms_output.put_line ('v_pr_found IS '||v_pr_found);
   
    If v_pr_found ='Y' then  
      pr_found_flag:= v_pr_found;
        --dbms_output.put_line (v_pr_found);      
       exit;       
    elsIF V_PR_FOUND ='N' then
         --dbms_output.put_line (v_pr_found);  
      pr_found_flag:= v_pr_found;
       exit;
    elsif   V_PR_FOUND ='null' then  
       --  dbms_output.put_line (v_pr_found);
      NULL;
    end if;
    
    
    If v_counter >10 then
       pr_found_flag:= 'In Process';
      -- dbms_output.put_line (pr_found_flag);
       exit;
    end if;
   

 end loop;
  
EXCEPTION
  when others then

     pr_found_flag:= 'Error';

END p_prism_status_track; 
/
