DROP PROCEDURE TOOL_OBLI_GET_HOLDING_RECORDS;

CREATE OR REPLACE PROCEDURE           TOOL_OBLI_GET_HOLDING_RECORDS IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       TOOL_OBLI_GET_HOLDING_RECORDS
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        11/24/2009          1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     TOOL_CLEAN_OBLI_HOLDING_TABLE
      Sysdate:         11/24/2009
      Date and Time:   11/24/2009, 10:24:14 AM, and 11/24/2009 10:24:14 AM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
BEGIN
   
   EXECUTE IMMEDIATE 'drop table UTI_TEMP_OBLI_DELPHI_OBLI';
   
   EXECUTE IMMEDIATE 'create table UTI_TEMP_OBLI_DELPHI_OBLI as
       select * from V_TOOL_OBLI_DELPHI_OBLIGATION  a
        where 1=1
         and exists (
           select 1
            from PRISM_PR_DELPHI_PO_HOLD b
           where a.N_SHIPMENT_NUMBER = b.SHIPMENT_NUMBER
             and a.N_LINE_NUMBER = b.LINE_NUM
             and a.N_DISTRIBUTION_NUMBER= b.DISTRIBUTION_NUM )
  order by N_LINE_NUMBER,N_SHIPMENT_NUMBER,N_DISTRIBUTION_NUMBER';
  
  EXECUTE IMMEDIATE 'drop table UTI_TEMP_OBLI_HOLDING_TBL';
  
  EXECUTE IMMEDIATE 'create table UTI_TEMP_OBLI_HOLDING_TBL as
      select * from V_TOOL_OBLI_HOLDING_TABLE  a
       where 1=1
        and exists (
         select 1
           from DELPHI_OBLIGATION b
           where a.N_SHIPMENT_NUMBER = b.N_SHIPMENT_NUMBER
             and a.N_LINE_NUMBER = b.N_LINE_NUMBER
             and a.N_DISTRIBUTION_NUMBER= b.N_DISTRIBUTION_NUMBER )
      order by a.N_LINE_NUMBER,a.N_SHIPMENT_NUMBER,a.N_DISTRIBUTION_NUMBER';
  
   EXCEPTION
   
   
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END TOOL_OBLI_GET_HOLDING_RECORDS; 
/
