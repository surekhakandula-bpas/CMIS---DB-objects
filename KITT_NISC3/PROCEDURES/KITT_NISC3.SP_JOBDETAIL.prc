DROP PROCEDURE SP_JOBDETAIL;

CREATE OR REPLACE PROCEDURE            sp_jobdetail(
                        p_job_id         IN number,
                        p_application    IN varchar2    DEFAULT 'SWB',
                        p_procedure_name IN varchar2,
                        p_input_parms    IN varchar2    DEFAULT NULL,
                        p_step_desc      IN varchar2    DEFAULT NULL,
                        p_counter        IN number      DEFAULT NULL,
                        p_comments       IN varchar2    DEFAULT NULL,
                        p_user_name      IN varchar2    DEFAULT NULL)
AS
 --**********************************************************************************************************************
 --Program Name    sp_jobdetail.sql
 --Author    J Feld
 --Create Date    04/17/2015
 --Purpose    This procedure will insert rows into the ARS JOB_DETAIL status table
 --
 --Modification History
 --**********************************************************************************************************************
/*
create table job_detail (
  job_id       number,
  application_name varchar2(100),
  procedure_name   varchar2(50),
  input_parms      varchar2(4000),
  step_descr       varchar2(100),
  counter          number,
  comments         varchar2(4000),
  user_name        varchar2(100),
  created_dt       date);

CREATE SEQUENCE PERSAD_ADM.job_detail_seq
START WITH 1000
INCREMENT BY 1
MINVALUE 0
NOCACHE 
NOCYCLE 
NOORDER 
NOKEEP
GLOBAL;
*/

BEGIN

-- insert into job_detail table

  INSERT INTO job_detail
    (job_id
    ,application_name
    ,procedure_name
    ,input_parms
    ,step_descr
    ,counter 
    ,comments
    ,user_name
    ,created_dt)
  VALUES
    (p_job_id
    ,p_application
    ,p_procedure_name
    ,p_input_parms
    ,p_step_desc
    ,p_counter
    ,p_comments
    ,p_user_name
    ,sysdate);

  COMMIT;

END sp_jobdetail;
/

GRANT EXECUTE ON SP_JOBDETAIL TO KITT_KFDBUSER;
