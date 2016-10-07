DROP PROCEDURE ETO_DELETE_DRAFT_TASK_ORDER;

CREATE OR REPLACE PROCEDURE           ETO_DELETE_DRAFT_TASK_ORDER (RemovedTaskOrderID in number:=0,
                                                                   UserID number:=0,
                                                                   StatusFlag out boolean,
                                                                   Msg out varchar2)
                                                             
IS

/******************************************************************************
   NAME:       DELETE_DRAFT_TASK_ORDER
   PURPOSE:   This procedure will remove a specific task orders and associated
              data from multiple tables.              

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        06/03/2009  Chao Yu       1. Created this procedure.
  
   Note: ETO Can delete a task order under following condition:
         1) in the ETO's queue (location = ETO) 
         2) in draft status 
         3) signature process (approval process) has not begun 
         
         1) + 3) conditions : N_OWNERSHIP_NUMBER = 101 
         2) condition : N_STATE_NUMBER = 101

******************************************************************************/


MyTaskOrderID number;
MyUserID number;
IsETO number;
IsAETO number;
TOExist number;

BEGIN

 /*
    MyTaskOrderID:=RemovedTaskOrderID;
    MyUserID:=UserID;
    
    select count(*) into IsETO
      from USER_ROLE 
     where N_USER_PROFILE_ID =MyUserID
       and N_ROLE_NUMBER = 101;
    
    if IsETO > 0 then

        select count(*) into TOExist
          from TASK_ORDER 
         where N_STATE_NUMBER = 101
           and N_OWNERSHIP_NUMBER=101
           and N_ETO_ID =MyUserID
           and N_TASK_ORDER_ID = MyTaskOrderID;
           
        if TOExist = 0 then
           
         Msg:='This task order can not be deleted.';
         
        end if;
    else
      
       select count(*) into IsAETO
         from USER_ROLE 
        where N_USER_PROFILE_ID =MyUserID
          and N_ROLE_NUMBER = 120;
          
       if  IsAETO > 0 then
       
        select count(*) into TOExist
          from TASK_ORDER 
         where N_STATE_NUMBER = 101
           and N_OWNERSHIP_NUMBER=101
           and N_ETO_ID in ( select N_ETO_ID 
                               from ETO_AETO 
                              where N_AETO_ID = MyUserID)
           and N_TASK_ORDER_ID = MyTaskOrderID;
       
         if TOExist = 0 then
           
         Msg:='This task order can not be deleted.';
         
         end if;
         
       else
       
         TOExist:= 0;
         Msg:='You can not delete this task order on your role.';
       
       end if;
       
       
    end if;  
        
   if TOExist = 1 then
 
       delete from SUBTASK_SERVICEAREA
       where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
              and b.N_TASK_ORDER_ID =MyTaskOrderID);
              
       DBMS_OUTPUT.PUT_LINE('SUBTASK_SERVICEAREA: ' ||SQL%ROWCOUNT);
      
      delete from SUBTASK_REGION
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID =MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('SUBTASK_REGION: ' ||SQL%ROWCOUNT);
     
      delete from SUB_TASK_FUNCTIONAL_WORK_AREA
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
     DBMS_OUTPUT.PUT_LINE('SUB_TASK_FUNCTIONAL_WORK_AREA: ' ||SQL%ROWCOUNT);
            
      delete from SUB_TASK_LABOR_CATEGORY
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
     DBMS_OUTPUT.PUT_LINE('SUB_TASK_LABOR_CATEGORY: ' ||SQL%ROWCOUNT);
     
      delete from SUB_TASK_ORDER_GTI
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('SUB_TASK_ORDER_GTI: ' ||SQL%ROWCOUNT);
         
      delete from SUB_TASK_SKILL_TYPE
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('SUB_TASK_SKILL_TYPE: ' ||SQL%ROWCOUNT);
      
    
      delete from DELIVERABLE
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('DELIVERABLE: ' ||SQL%ROWCOUNT);
      
             
      delete from ODC_COST
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('ODC_COST: ' ||SQL%ROWCOUNT); 
      
      delete from ALLOCATION
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('ALLOCATION: ' ||SQL%ROWCOUNT); 
      
      delete from TRAVEL_COST
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
     DBMS_OUTPUT.PUT_LINE('TRAVEL_COST: ' ||SQL%ROWCOUNT); 
         
      delete from TRANSACTION
      where N_TASK_ORDER_ID = MyTaskOrderID;
      
      DBMS_OUTPUT.PUT_LINE('TRANSACTION: ' ||SQL%ROWCOUNT);
      
      delete from TRANSACTION
       where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);

      DBMS_OUTPUT.PUT_LINE('TRANSACTION: ' ||SQL%ROWCOUNT);
      
      
      delete from NOTE_COMMENT
      where N_TASK_ORDER_ID = MyTaskOrderID;
      DBMS_OUTPUT.PUT_LINE('NOTE_COMMENT: ' ||SQL%ROWCOUNT);
     
      delete from ATTACHMENT 
       where upper(c_object_type) ='SUBTASK'
         and N_OBJECT_ID in (select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER 
                              where N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('ATTACHMENT: ' ||SQL%ROWCOUNT);
             
      delete from ATTACHMENT 
       where upper(c_object_type) ='TASKORDER'
         and N_OBJECT_ID = MyTaskOrderID;
      DBMS_OUTPUT.PUT_LINE('ATTACHMENT: ' ||SQL%ROWCOUNT);
      
      delete from PROCUREMENT_REQUEST
       where c_task_order_number = MyTaskOrderID;
      DBMS_OUTPUT.PUT_LINE('PROCUREMENT_REQUEST: ' ||SQL%ROWCOUNT);
       
      delete from CONTRACT_ELEMENT
       where N_TASK_ORDER_ID = MyTaskOrderID;
       DBMS_OUTPUT.PUT_LINE('CONTRACT_ELEMENT: ' ||SQL%ROWCOUNT);
      
      delete from CONTRACT_PDF
       where N_TASK_ORDER_ID = MyTaskOrderID;
     DBMS_OUTPUT.PUT_LINE('CONTRACT_PDF: ' ||SQL%ROWCOUNT);
   
       delete from EXTENDED_ELEMENT
      where upper(C_OBJECT_TYPE) ='TASK_ORDER'
        and N_OBJECT_ID = MyTaskOrderID;
       DBMS_OUTPUT.PUT_LINE('EXTENDED_ELEMENT: ' ||SQL%ROWCOUNT);
        
         delete from USER_ALERT
      where upper(C_OBJECT_TYPE) ='TASK_ORDER'
        and N_OBJECT_ID = MyTaskOrderID;  
     DBMS_OUTPUT.PUT_LINE('USER_ALERT: ' ||SQL%ROWCOUNT);

      delete from REASON_ESTIMATE_CHANGE
       where N_TASK_ORDER_ID = MyTaskOrderID;
     DBMS_OUTPUT.PUT_LINE('REASON_ESTIMATE_CHANGE: ' ||SQL%ROWCOUNT);


      delete from NTP
      where C_OBJECT_TYPE ='TASK_ORDER'
        and N_object_id = MyTaskOrderID;
     DBMS_OUTPUT.PUT_LINE('NTP: ' ||SQL%ROWCOUNT);
     
      delete SUB_TASK_CANCELLATION
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('SUB_TASK_CANCELLATION: ' ||SQL%ROWCOUNT);       
       
      delete from SUB_TASK_ORDER
      where N_SUB_TASK_ORDER_ID in (
           select N_SUB_TASK_ORDER_ID from SUB_TASK_ORDER a, TASK_ORDER b
            where a.N_TASK_ORDER_ID=b.N_TASK_ORDER_ID
             and b.N_TASK_ORDER_ID = MyTaskOrderID);
      DBMS_OUTPUT.PUT_LINE('SUB_TASK_ORDER: ' ||SQL%ROWCOUNT); 
                      
      delete from TASK_ORDER
      where N_TASK_ORDER_ID = MyTaskOrderID;

      DBMS_OUTPUT.PUT_LINE('TASK_ORDER: ' ||SQL%ROWCOUNT);
  

      commit; 
      
      StatusFlag:=true;
      Msg:='Successful';
      
    else
   
      StatusFlag:=false;
      
      
    end if;
    
   */
   null;
     
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
      Rollback;
      StatusFlag:=false;
      Msg:='Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'. Task Order '||MyTaskOrderID||':has NOT been deleted successfully.';
      
      dbms_output.put_line(Msg);
      RAISE;
END; 
/
