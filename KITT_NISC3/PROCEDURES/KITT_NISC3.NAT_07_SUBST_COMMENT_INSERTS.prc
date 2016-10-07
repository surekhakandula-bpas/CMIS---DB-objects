DROP PROCEDURE NAT_07_SUBST_COMMENT_INSERTS;

CREATE OR REPLACE PROCEDURE            "NAT_07_SUBST_COMMENT_INSERTS" (
   InvoiceID    NUMBER)
AS
   invoice_no                  NUMBER;
   comments_array              apex_application_global.vc_arr2;
   n_invoice_no                NUMBER;
   n_invoice_item_no           NUMBER;
   c_mis_invoice_item_number   VARCHAR2 (30);
   -- c_cont_comments       VARCHAR2(1000);
   c_nat_cont_comments         VARCHAR2 (4000);
   mis_ID_Count                NUMBER;
BEGIN
   invoice_no := InvoiceID;

   FOR cur_comments
      IN (SELECT n.invoice_number,
                 i.n_invoice_item_id,
                 n.external_id,
                 n.contractor_comments
            FROM nat_invoice_line_item n, invoice_item i
           WHERE n.invoice_number = invoice_no AND n.external_id = i.n_mis_invoice_item_id --- for testing
 --AND n.EXTERNAL_ID IN ('3343940675', '3316183565', '3316183563', '3300550151', '3290825853', '3273046657', '3254759751', '3252987193', '3300552803')
                                                               --- for testing
                                                    --AND rownum          <=10
         )
   LOOP
      n_invoice_no := cur_comments.invoice_number;
      n_invoice_item_no := cur_comments.n_invoice_item_id;
      c_mis_invoice_item_number := cur_comments.external_id;
      c_nat_cont_comments := cur_comments.contractor_comments;

      --- find out the existance of duplicate MIS_INVOICE_ITEM_IDs in NAT comments table
      SELECT COUNT (*)
        INTO mis_ID_Count
        FROM INV_SUBST_COMM_FROM_NAT
       WHERE MIS_INVOICE_ITEM_ID = c_mis_invoice_item_number;

      --and INVOICE_NUMBER = invoice_no;
      IF (mis_ID_Count > 0)
      THEN
         --- if exists add '000' to MIS_INVOICE_ITEM_ID/c_mis_invoice_item_number
         c_mis_invoice_item_number := c_mis_invoice_item_number || '00';

         --dbms_output.put_line(mis_ID_Count);
         --dbms_output.put_line(c_mis_invoice_item_number);
         --- get the invoice item id from INVOICE_ITEM table for this new mis-invoice_item_number with '00' appended
         SELECT N_INVOICE_ITEM_ID
           INTO n_invoice_item_no
           FROM invoice_item
          WHERE N_MIS_INVOICE_ITEM_ID = c_mis_invoice_item_number;
      --dbms_output.put_line(n_invoice_item_no);
      END IF;

      IF (c_nat_cont_comments IS NOT NULL)
      THEN
         comments_array :=
            APEX_UTIL.string_to_table (c_nat_cont_comments, '|');

         FOR i IN 1 .. comments_array.COUNT
         LOOP
            INSERT INTO INV_SUBST_COMM_FROM_NAT
                 VALUES (n_invoice_no,
                         n_invoice_item_no,
                         comments_array (i),
                         c_mis_invoice_item_number);
         END LOOP;
      ELSE
         INSERT INTO INV_SUBST_COMM_FROM_NAT
              VALUES (n_invoice_no,
                      n_invoice_item_no,
                      c_nat_cont_comments,
                      c_mis_invoice_item_number);
      END IF;
   END LOOP;

   COMMIT;
END NAT_07_SUBST_COMMENT_INSERTS;
/
