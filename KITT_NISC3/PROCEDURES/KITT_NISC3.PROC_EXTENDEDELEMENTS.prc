DROP PROCEDURE PROC_EXTENDEDELEMENTS;

CREATE OR REPLACE PROCEDURE              "PROC_EXTENDEDELEMENTS" AS 
    c_N_ElementID number(10,0);
    c_N_Object_Id number;
    c_c_ElementType varchar(25);
    c_c_Object_Type varchar(25);
    c_CB_Element CLOB;
    c_Task_Order_Name varchar(1000);
    c_TaskOrderTitle varchar(1000);
    tempCount number;
    countcombo number;
    c_ccompare_Task_Order_Name varchar(1000);
    c_Changed char(1);
    cursor c_Extendedelement is
      select N_ELEMENT_ID, N_OBJECT_ID, C_ELEMENT_TYPE, C_OBJECT_TYPE, CB_ELEMENT,TaskOrderName,TaskOrderTitle from
      (SELECT 
          '' N_ELEMENT_ID
          ,B.K2_TO_ID N_OBJECT_ID
          ,'C_PWS' C_ELEMENT_TYPE
          ,'Task Order' C_OBJECT_TYPE
          ,d.c_sub_task_order_name TaskOrderName
          ,d.c_sub_task_order_title TaskOrderTitle
          ,To_Clob(A.Description) CB_ELEMENT
        FROM k3_PWS A
        , V_CUSTOM_STO_MAP B
        ,Kitt_NISC3.sub_task_order D
        where a.sub_task_order_id = b.K3_STO_ID
        and b.K2_STO_ID = D.N_Sub_task_Order_Id
        
         union all
         
        -- Provisions Statements
        SELECT 
          '' N_ELEMENT_ID
          ,B.K2_TO_ID N_OBJECT_ID
          ,'C_PROVISIONS' C_ELEMENT_TYPE
          ,'Task Order' C_OBJECT_TYPE
         ,d.c_sub_task_order_name TaskOrderName
          ,d.c_sub_task_order_title TaskOrderTitle
          ,To_Clob(A.Description) CB_ELEMENT
        FROM K3_Provision A
        , V_CUSTOM_STO_MAP B
        ,Kitt_NISC3.sub_task_order D
        where a.sub_task_order_id = b.K3_STO_ID
        and b.K2_STO_ID = D.N_Sub_task_Order_Id
        
        Union all
        
        -- Top Exe Summary Statements
        SELECT 
          '' N_ELEMENT_ID
          ,b.K2_TO_ID N_OBJECT_ID
          ,'C_SUMMARY' C_ELEMENT_TYPE
          ,'Task Order' C_OBJECT_TYPE
          ,'' TaskOrderName
          ,'' TaskOrderTitle
          ,A.Description CB_ELEMENT
        FROM K3_Top_Exe_Summary A
        , (SELECT DISTINCT K3_TO_ID, K2_TO_ID FROM V_CUSTOM_STO_MAP) B
        where a.task_order_id = B.K3_TO_ID 
        
        Union all
        
        -- Product Statements
        SELECT 
          '' N_ELEMENT_ID
         ,b.K2_TO_ID N_OBJECT_ID
          ,'C_PRODUCTS' C_ELEMENT_TYPE
          ,'Task Order' C_OBJECT_TYPE
          ,d.c_sub_task_order_name TaskOrderName
          ,d.c_sub_task_order_title TaskOrderTitle
          ,to_clob('PRODUCT TITLE: ' || To_Char(a.title) || '<br/>' 
           ||'PRODUCT DESCRIPTION: ' || To_Char(a.description) || '<br/>' 
           ||'PRODUCT DUE DATE DESCRIPTION: ' || a.due_date_desc || '<br/>') CB_ELEMENT
        FROM K3_Product A
        , V_CUSTOM_STO_MAP B
        ,Kitt_NISC3.sub_task_order D
        where a.sub_task_order_id = b.K3_STO_ID
        and b.K2_STO_ID = D.N_Sub_task_Order_Id
        
        union all
        
        -- Deliverable Statements
        SELECT 
          '' N_ELEMENT_ID
         ,b.K2_TO_ID N_OBJECT_ID
          ,'C_PRODUCTS' C_ELEMENT_TYPE
          ,'Task Order' C_OBJECT_TYPE
          ,d.c_sub_task_order_name TaskOrderName
          ,d.c_sub_task_order_title TaskOrderTitle
          ,to_clob(A.Description) CB_ELEMENT
        FROM k3_deliverable A
        , V_CUSTOM_STO_MAP B
        ,Kitt_NISC3.sub_task_order D
        where a.sub_task_order_id = b.K3_STO_ID
        and b.K2_STO_ID = D.N_Sub_task_Order_Id
        
        Union all
        
        -- Goal and Metric Statements
        SELECT 
          '' N_ELEMENT_ID
          ,b.K2_TO_ID N_OBJECT_ID
          ,'C_GOALS' C_ELEMENT_TYPE
          ,'Task Order' C_OBJECT_TYPE
          ,d.c_sub_task_order_name TaskOrderName
          ,d.c_sub_task_order_title TaskOrderTitle
          ,to_clob('Title: ' || a.title || '<br/>'
           ||'GOAL: ' || a.Goal || '<br/>'
           ||'METRICS: ' || a.METRICS || '<br/>' 
           ||'MEASURE SUCCESS: ' || a.MEASURE_SUCCESS || '<br/>'
           ||'STRENGTH: ' || a.STRENGTH || '<br/>'
           ||'ACCEPTANCE: ' || a.ACCEPTANCE || '<br/>'
           ||'WEEKNESS: ' || a.WEEKNESS || '<br/>'
           ||'DEFICENCY: ' || a.DEFICENCY || '<br/>'
           ||'METRIC_DESC: ' || a.METRIC_DESC || '<br/>') CB_ELEMENT
        FROM K3_Goal_And_Metric A
        , V_CUSTOM_STO_MAP B
        ,Kitt_NISC3.sub_task_order D
        where a.sub_task_order_id = b.K3_STO_ID
        and b.K2_STO_ID = D.N_Sub_task_Order_Id) 
        --where N_OBJECT_ID = 11522
        order by N_OBJECT_ID, C_ELEMENT_TYPE, TaskOrderName;
        
BEGIN
  open c_Extendedelement;
  loop
    fetch c_Extendedelement into  c_N_ElementID,c_N_Object_Id,c_c_ElementType,c_c_Object_Type,c_CB_Element,c_Task_Order_Name,c_TaskOrderTitle;
    c_Changed := 'N';
    --verify if the Task Order ID and element Type Exist
    if c_ccompare_Task_Order_Name is not null then
      if c_ccompare_Task_Order_Name != c_Task_Order_Name then
        c_ccompare_Task_Order_Name := c_Task_Order_Name;
        c_Changed := 'Y';
      end if;
    else
      c_ccompare_Task_Order_Name := c_Task_Order_Name;
      c_Changed := 'Y';
    end if;
    select count(n_Object_Id) into countcombo from Kitt_NISC3.extended_element  
                  where Kitt_NISC3.extended_element.N_Object_ID = c_N_Object_Id 
                          and Kitt_NISC3.extended_element.C_Element_Type = c_c_ElementType;
    if countcombo > 0 then
    -- Update existing row
        if c_c_ElementType != 'C_SUMMARY' then
              if c_Changed = 'N' then
                   update kitt_Nisc3.extended_element
                      set CB_Element = To_Clob(CB_Element || '<br/>') || To_Clob(nvl(c_CB_Element,chr(10)))
                      where N_Object_ID = c_N_Object_Id
                      and C_Element_Type = c_c_ElementType;
                else
                   update kitt_Nisc3.extended_element
                      set CB_Element = To_Clob(CB_Element || '<br/>' || To_Clob(To_Clob('<b>' || c_Task_Order_Name || ': ' || c_TaskOrderTitle || '</b><br/>') || To_Clob(nvl(c_CB_Element,chr(10)))))
                      where N_Object_ID = c_N_Object_Id
                      and C_Element_Type = c_c_ElementType;
                end if;
              commit;
        end if;
    else    
    -- Insert new row
      if  c_c_ElementType = 'C_SUMMARY' then
           insert into KITT_NISC3.extended_element(n_Element_ID,N_Object_ID,C_Element_Type,C_Object_Type,CB_Element) 
          values(Kitt_NISC3.Seq_Extended_Element.nextval
            ,c_N_Object_Id
            ,c_c_ElementType
            ,c_c_Object_Type
            ,To_Clob(nvl(c_CB_Element,chr(10))));       
      else
        insert into KITT_NISC3.extended_element(n_Element_ID,N_Object_ID,C_Element_Type,C_Object_Type,CB_Element) 
          values(Kitt_NISC3.Seq_Extended_Element.nextval
            ,c_N_Object_Id
            ,c_c_ElementType
            ,c_c_Object_Type
            ,To_Clob(To_Clob('<b>' || c_Task_Order_Name || ': ' || c_TaskOrderTitle || '</b><br/>') || To_Clob(nvl(c_CB_Element,chr(10)))));
      end if;
      commit;
    end if;
    exit when c_Extendedelement%notfound;
  end loop;
END PROC_EXTENDEDELEMENTS;
/
