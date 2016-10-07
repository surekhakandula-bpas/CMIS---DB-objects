DROP PROCEDURE SP_KFDBUSER_SEQUENCE_RESET;

CREATE OR REPLACE PROCEDURE               SP_KFDBUSER_SEQUENCE_RESET(
                        p_PStatus          OUT VARCHAR2 )  
/*
---------------------------------------------------------------------------------------------------
  Object Name:  SP_KFDBUSER_SEQUENCE_REFRESH
  Author:       J Feld
  Date Created: 06/15/2015    
  Purpose: Reset sequences after refresh
  
  Modification History:
---------------------------------------------------------------------------------------------------  
*/                              
IS
   CURSOR GetCursorsToSync IS
   SELECT pd.sequence_name, pd.last_number last_number_pd,
          qa.last_number last_number_qa, qa.cache_size
     FROM DBA_sequences@KITT_KFDBUSER_KITTD pd
     JOIN USER_sequences qa
       on qa.sequence_name = pd.sequence_name
    WHERE qa.last_number != pd.last_number
      AND SEQUENCE_OWNER='KITT_KFDBUSER';

   TYPE CursorsTableType IS
   TABLE OF GetCursorsToSync%ROWTYPE INDEX BY pls_integer;  
      CursorsTable  CursorsTableType;
      i             pls_integer;

   PROCEDURE Reset_Sequence(
      sequence_name IN VARCHAR2,
      source_value  IN NUMBER,
      target_value  IN NUMBER,
      cache_size    IN NUMBER)
   IS
      l_sql    VARCHAR2(4000);
      l_temp   NUMBER(30);
   BEGIN
      IF source_value <= target_value THEN
         RETURN;
      END IF;

      dbms_output.put_line(sequence_name || ' ' || source_value || ' ' || target_value);
      IF cache_size > 0 THEN
         l_sql := 'alter sequence '|| sequence_name || ' nocache';
         dbms_output.put_line(l_sql);
         EXECUTE IMMEDIATE l_sql;
      END IF;

      l_sql := 'alter sequence '|| sequence_name || ' increment by ' || TO_CHAR(source_value-target_value);
      dbms_output.put_line(l_sql);
      EXECUTE IMMEDIATE l_sql;

      l_sql := 'SELECT ' || sequence_name || '.nextval FROM dual';
      dbms_output.put_line(l_sql);
      EXECUTE IMMEDIATE l_sql INTO l_temp;

      dbms_output.put_line(l_temp);

      l_sql := 'alter sequence ' || sequence_name || ' increment by 1';
      dbms_output.put_line(l_sql);
      EXECUTE IMMEDIATE l_sql;

      IF cache_size > 0 THEN
         l_sql := 'alter sequence '|| sequence_name || ' cache ' || TO_CHAR(cache_size);
         dbms_output.put_line(l_sql);
         EXECUTE IMMEDIATE l_sql;
      END IF;

      COMMIT;
   END Reset_Sequence;

BEGIN
   OPEN GetCursorsToSync;
   FETCH GetCursorsToSync BULK COLLECT INTO CursorsTable;
   CLOSE GetCursorsToSync;
   COMMIT;

   i := CursorsTable.FIRST;
   WHILE i IS NOT NULL LOOP
      Reset_Sequence(CursorsTable(i).sequence_name, CursorsTable(i).last_number_pd,
         CursorsTable(i).last_number_qa, CursorsTable(i).cache_size);
      i := CursorsTable.NEXT(i);
   END LOOP;
END;
/

GRANT EXECUTE ON SP_KFDBUSER_SEQUENCE_RESET TO SNAMBIAR;
