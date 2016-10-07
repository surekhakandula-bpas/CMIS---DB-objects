DROP PROCEDURE TOOL_OBLI_CREATE_CHANGE_TBL;

CREATE OR REPLACE PROCEDURE           TOOL_OBLI_CREATE_CHANGE_TBL IS
tmpVar NUMBER;

BEGIN
   
   EXECUTE IMMEDIATE 'create table UTI_TEMP_OBLI_CHANGE_PR_MOD# as

       SELECT n_line_number, n_shipment_number, n_distribution_number,
              c_charge_account, c_task_number, c_pr_project_number,        
              quantity_ordered, quantity_cancelled,        
              c_pr_number, n_mod_number
        FROM   uti_temp_obli_holding_tbl

        MINUS
   
       SELECT n_line_number, n_shipment_number, n_distribution_number,
              c_charge_account, c_task_number, c_pr_project_number,
              quantity_ordered, quantity_cancelled,
              c_pr_number, n_mod_number
        FROM   uti_temp_obli_delphi_obli';



   EXECUTE IMMEDIATE 'create table UTI_TEMP_OBLI_CHANGE_FUND_EXP as

      SELECT n_line_number, n_shipment_number, n_distribution_number,
             c_charge_account, c_task_number, c_pr_project_number,
             quantity_ordered, quantity_cancelled,
             d_expiration_date, c_funding_type  
       FROM   uti_temp_obli_holding_tbl

      MINUS
      
      SELECT n_line_number, n_shipment_number, n_distribution_number,
             c_charge_account, c_task_number, c_pr_project_number,
             quantity_ordered, quantity_cancelled,
             d_expiration_date, c_funding_type 
       FROM   uti_temp_obli_delphi_obli';
       
       
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_OBLI_CREATE_CHANGE_TBL; 
/
