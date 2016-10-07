DROP PROCEDURE INV_SBST_DATA_LOAD_FILES;

CREATE OR REPLACE PROCEDURE            "INV_SBST_DATA_LOAD_FILES"
AS
  invoice_no NUMBER := 67;
  v_display_names_array apex_application_global.vc_arr2;
  v_physical_names_array apex_application_global.vc_arr2;
  invoice_number          NUMBER;
  invoice_item_id         NUMBER;
  mis_invoice_item_number VARCHAR2(30);
  display_file_name       VARCHAR2(1000);
  nat_display_file_names  VARCHAR2(4000);
  physical_file_name      VARCHAR2(1000);
  nat_physical_file_names VARCHAR2(4000);
  mis_ID_Count            NUMBER;
BEGIN
  FOR cur_filenames IN
  (SELECT n.invoice_number,
    i.n_invoice_item_id,
    n.external_id,
    n.DISPLAY_FILENAMES,
    n.FTP_FILE_URLS
  FROM nat_invoice_line_item n,
    invoice_item i
  WHERE n.invoice_number = invoice_no
  AND n.external_id      = i.n_mis_invoice_item_id
    --- for testing
    --AND n.EXTERNAL_ID IN ('3343940675', '3316183565', '3316183563', '3300550151', '3290825853', '3273046657', '3254759751', 
    --'3252987193', '3300552803')
    --- for testing
    --AND rownum          <=3
  )
  LOOP
    invoice_number          := cur_filenames.invoice_number;
    invoice_item_id         := cur_filenames.n_invoice_item_id;
    mis_invoice_item_number := cur_filenames.external_id;
    nat_display_file_names  := cur_filenames.DISPLAY_FILENAMES;
    nat_physical_file_names := cur_filenames.FTP_FILE_URLS;
    --dbms_output.put_line( mis_invoice_item_id );
    --- find out the existance of duplicate MIS_INVOICE_ITEM_IDs in NAT data files table
    SELECT COUNT(*)
    INTO mis_ID_Count
    FROM INV_SUBST_FILES_FROM_NAT
    WHERE MIS_INVOICE_ITEM_ID = mis_invoice_item_number;
    --- if exists add '000' to MIS_INVOICE_ITEM_ID/mis_invoice_item_id
    IF (mis_ID_Count           > 0) THEN
      mis_invoice_item_number := mis_invoice_item_number || '00';
      --dbms_output.put_line(mis_ID_Count);
      --dbms_output.put_line(mis_invoice_item_number);
      --- get the invoice item id from INVOICE_ITEM table for this new mis-invoice_item_number with '00' appended
      SELECT N_INVOICE_ITEM_ID
      INTO invoice_item_id
      FROM invoice_item
      WHERE N_MIS_INVOICE_ITEM_ID = mis_invoice_item_number;
      --dbms_output.put_line(invoice_item_id);
    END IF;
    IF (nat_display_file_names IS NOT NULL) THEN
      v_display_names_array    := apex_util.string_to_table(nat_display_file_names, '|');
      v_physical_names_array   := apex_util.string_to_table(nat_physical_file_names, '|');
      FOR i IN 1..v_display_names_array.count
      LOOP
        v_physical_names_array(i):= REPLACE(v_physical_names_array(i), 'ftp://172.27.17.81/Attachments/PROD/' || invoice_no || '/', '\NAT\\' || invoice_no || '\\');
        --dbms_output.put_line(v_physical_names_array(i));
        --, 'ftp://172.27.17.81/Attachments/PROD', '/NAT'));
        INSERT
        INTO INV_SUBST_FILES_FROM_NAT VALUES
          (
            invoice_number,
            invoice_item_id,
            v_display_names_array(i),
            v_physical_names_array(i),
            mis_invoice_item_number
          );
      END LOOP;
    ELSE
      INSERT
      INTO INV_SUBST_FILES_FROM_NAT VALUES
        (
          invoice_number,
          invoice_item_id,
          nat_display_file_names,
          nat_physical_file_names,
          mis_invoice_item_number
        );
    END IF;
  END LOOP;
  COMMIT;
END INV_SBST_DATA_LOAD_FILES;
/
