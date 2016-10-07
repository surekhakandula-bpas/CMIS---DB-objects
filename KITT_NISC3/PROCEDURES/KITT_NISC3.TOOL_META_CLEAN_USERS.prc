DROP PROCEDURE TOOL_META_CLEAN_USERS;

CREATE OR REPLACE PROCEDURE            TOOL_META_CLEAN_USERS (MyUserId number,
                                                   MyStatus in out varchar2)
IS

/******************************************************************************
   NAME:       TOOL_META_CLEAN_USERS
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/26/2010    Chao Yu      1. Created this procedure.

   NOTES:

    Only clean up the users who doesn't own a task order 
******************************************************************************/
BEGIN
   
   
    delete from AETO_TASK_ORDER
     where N_AETO_ID = MyUserId;
     
     
    delete from ETO_AETO 
     where N_AETO_ID = MyUserId;
     
     delete from ETO_AETO_HOLDING 
     where N_AETO_ID = MyUserId;
     
    delete from TOM_ATOM 
     where N_ATOM_ID = MyUserId;
     
    delete from TOM_ATOM_HOLDING 
     where N_ATOM_ID = MyUserId;
    
    delete from ETO_BUSMGR 
     where N_BUSMGR_ID = MyUserId;
     
    delete from ETO_BUSMGR_HOLDING 
     where N_BUSMGR_ID = MyUserId;
    
    delete from USER_ROLE 
     where N_USER_PROFILE_ID= MyUserId;
    
    delete from USER_PROFILE 
    where N_USER_PROFILE_ID = MyUserId;

    commit;

    MyStatus:='Yes';
  
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
     
       MyStatus:='Failed to delete user '||MyUserId ||' from NISC3.';
       rollback;
       RAISE;
END; 
/
