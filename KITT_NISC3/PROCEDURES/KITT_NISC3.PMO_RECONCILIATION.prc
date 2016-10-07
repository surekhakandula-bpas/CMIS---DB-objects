DROP PROCEDURE PMO_RECONCILIATION;

CREATE OR REPLACE PROCEDURE            PMO_RECONCILIATION IS


/******************************************************************************
   NAME:       RECONCILIATION
   PURPOSE:   This procedure will reconciate the records found in Delphi against records found in KITT.

   REVISIONS:
   Ver        Date        Author                   Description
   ---------  ----------  ---------------          ------------------------------------
   1.0        05/19/2009  Nicholson Prosper           1. Created this procedure.

   Note: This procedure will run every to perform the reconciation process
         1) If a variance is found between KITT_Balance and Delphi Balance an update will be on the Delphi_Obligation table
         2) An update will be perform is the bal_viriance amount is not equal to zero

******************************************************************************/


CURSOR csr_quantity IS SELECT
                                                       T1.line_number||'-'||T1.shipment_number||'-'||T1.distribution_number as LSD,
                                                        T1.line_number,T1.shipment_number,T1.distribution_number
                                                        ,T1.n_delphi_obligation_id
                                                       ,T1.C_RECONCILIATION_STATUS,
                                                       T1. Accounting_String,
                                                        T2.Delphi_Obligated_Amount,
                                                        T1.KITT_Obligated_Amount ,
                                                        (T2.Delphi_Obligated_Amount - T1.KITT_Obligated_Amount) as Obligated_Variance,
                                                        T2.Delphi_paid_amount,
                                                        T1.Kitt_Paid_Amount,
                                                        (T2.Delphi_paid_amount- T1.Kitt_Paid_Amount) as Paid_Variance,
                                                        T2.Delphi_Balance as Delphi_Bal,
                                                        T1.KITT_BALANCE as KITT_Bal,
                                                        (T2.Delphi_Balance - T1.KITT_BALANCE) as Bal_Variance
                                FROM
                                           (SELECT
                                                                      b.c_delphi_code as Accounting_String,
                                                                      b.C_RECONCILIATION_STATUS as C_RECONCILIATION_STATUS,
                                                                       b.n_delphi_obligation_id as n_delphi_obligation_id,
                                                                       b.n_line_number as line_number,
                                                                       b.n_shipment_number as shipment_number,
                                                                       b.n_distribution_number as distribution_number,
                                                                       e. KITT_Obligated_Amount,
                                                                       nvl(a.Kitt_Paid_Amount,0) as Kitt_Paid_Amount,
                                                                    --        nvl(c.n_delphi_offset_amount,0) as delphi_offset_amount,
                                                                    --        nvl(d.Kitt_credit_Amount,0) as kitt_credit_amount,
                                                                    --        nvl(b.quantity_ordered,0) as Kitt_quantity_ordered,
                                                                    --        nvl(b.quantity_cancelled,0) as kitt_quantity_cancelled,
                                                                       (b.quantity_ordered - b.quantity_cancelled - nvl(c.n_delphi_offset_amount,0) - nvl(a.Kitt_Paid_Amount,0) + nvl(d.Kitt_credit_Amount,0)) as KITT_BALANCE
                                         FROM
       -- get KITT Paid Amount
                                                          (
                                                               SELECT
                                                                                   n_delphi_obligation_id,
                                                                                   sum(nvl(N_amount,0)) as Kitt_Paid_Amount
                                                               FROM             payment_instruction_item
                                                               GROUP BY        n_delphi_obligation_id
                                                           ) a,
                                                           delphi_obligation b,
                                                           delphi_offset c,
                                                           -- get KITT Credit Amount  --we may not need this
                                                           (
                                                               SELECT
                                                                   n_delphi_obligation_id
                                                                --,nvl(b.quantity_ordered,0) - nvl(b.quantity_cancelled,0) as KITT_Obligated_Amount
                                                                   ,SUM(NVL(N_adjusted_amount,0)) as Kitt_credit_Amount
                                                              FROM         delphi_obligation_adjustment
                                                               GROUP BY  n_delphi_obligation_id
                                                           ) d,
                                                           --- - get KITT Obligated Amount
                                                        (
                                                            SELECT
                                                                                n_delphi_obligation_id,
                                                                                sum(nvl(quantity_ordered - quantity_cancelled, 0)) as KITT_Obligated_Amount
                                                               FROM         DELPHI_OBLIGATION
                                                               GROUP BY   n_delphi_obligation_id
                                                          ) e
                                                      WHERE                b.n_delphi_obligation_id =a.n_delphi_obligation_id(+)
                                                     AND b.n_delphi_obligation_id =c.n_delphi_obligation_id(+)
                                                     AND b.n_delphi_obligation_id =d.n_delphi_obligation_id(+)
                                                     AND b.n_delphi_obligation_id =e.n_delphi_obligation_id(+)
                                                     ORDER BY            b.n_line_number,b.n_shipment_number,  b.n_distribution_number
                                                   ) T1,
                                                   (
                                                       SELECT
                                                                           line_num as line_number,
                                                                           shipment_number,
                                                                           distribution_num as distribution_number,
                                                                           SUM(NVL( quantity_ordered - QUANTITY_CANCELLED,0)) as Delphi_Obligated_Amount,
                                                                           -- sum(nvl(net_qty_ordered - quantity_ordered,0)) as Delphi_Obligated_Amount,
                                                                           SUM(NVL(quantity_billed,0)) as Delphi_paid_amount,
                                                                           SUM(NVL(net_qty_ordered - quantity_billed,0)) as Delphi_Balance
                                                       FROM            delphi_po
                                                       GROUP BY     line_num,shipment_number, distribution_num
                                                       ORDER BY     line_number, shipment_number, distribution_number
                                                   ) T2
                                                        WHERE               T1.line_number = T2.line_number
                                                        AND                    T1.shipment_number = T2.shipment_number
                                                        AND                    T1.distribution_number = T2.distribution_number
                                                        AND                    (T2.Delphi_Balance - T1.KITT_BALANCE) <> 0 ;





--  Second Cursor to test the part of the query  where values is equal to zero
/****************************************************************************************************************
*****************************************************************************************************************
*****************************************************************************************************************/
CURSOR csr_tquantity IS SELECT
                                                       T1.line_number||'-'||T1.shipment_number||'-'||T1.distribution_number as LSD,
                                                        T1.line_number,T1.shipment_number,T1.distribution_number
                                                        ,T1.n_delphi_obligation_id
                                                       ,T1.C_RECONCILIATION_STATUS,
                                                       T1. Accounting_String,
                                                        T2.Delphi_Obligated_Amount,
                                                        T1.KITT_Obligated_Amount ,
                                                        (T2.Delphi_Obligated_Amount - T1.KITT_Obligated_Amount) as Obligated_Variance,
                                                        T2.Delphi_paid_amount,
                                                        T1.Kitt_Paid_Amount,
                                                        (T2.Delphi_paid_amount- T1.Kitt_Paid_Amount) as Paid_Variance,
                                                        T2.Delphi_Balance as Delphi_Bal,
                                                        T1.KITT_BALANCE as KITT_Bal,
                                                        (T2.Delphi_Balance - T1.KITT_BALANCE) as Bal_Variance
                                FROM
                                           (SELECT
                                                                      b.c_delphi_code as Accounting_String,
                                                                      b.C_RECONCILIATION_STATUS as C_RECONCILIATION_STATUS,
                                                                       b.n_delphi_obligation_id as n_delphi_obligation_id,
                                                                       b.n_line_number as line_number,
                                                                       b.n_shipment_number as shipment_number,
                                                                       b.n_distribution_number as distribution_number,
                                                                       e. KITT_Obligated_Amount,
                                                                       nvl(a.Kitt_Paid_Amount,0) as Kitt_Paid_Amount,
                                                                    --        nvl(c.n_delphi_offset_amount,0) as delphi_offset_amount,
                                                                    --        nvl(d.Kitt_credit_Amount,0) as kitt_credit_amount,
                                                                    --        nvl(b.quantity_ordered,0) as Kitt_quantity_ordered,
                                                                    --        nvl(b.quantity_cancelled,0) as kitt_quantity_cancelled,
                                                                       (b.quantity_ordered - b.quantity_cancelled - nvl(c.n_delphi_offset_amount,0) - nvl(a.Kitt_Paid_Amount,0) + nvl(d.Kitt_credit_Amount,0)) as KITT_BALANCE
                                         FROM
       -- get KITT Paid Amount
                                                          (
                                                               SELECT
                                                                                   n_delphi_obligation_id,
                                                                                   sum(nvl(N_amount,0)) as Kitt_Paid_Amount
                                                               FROM             payment_instruction_item
                                                               GROUP BY        n_delphi_obligation_id
                                                           ) a,
                                                           delphi_obligation b,
                                                           delphi_offset c,
                                                           -- get KITT Credit Amount  --we may not need this
                                                           (
                                                               SELECT
                                                                   n_delphi_obligation_id
                                                                --,nvl(b.quantity_ordered,0) - nvl(b.quantity_cancelled,0) as KITT_Obligated_Amount
                                                                   ,SUM(NVL(N_adjusted_amount,0)) as Kitt_credit_Amount
                                                              FROM         delphi_obligation_adjustment
                                                               GROUP BY  n_delphi_obligation_id
                                                           ) d,
                                                           --- - get KITT Obligated Amount
                                                        (
                                                            SELECT
                                                                                n_delphi_obligation_id,
                                                                                sum(nvl(quantity_ordered - quantity_cancelled, 0)) as KITT_Obligated_Amount
                                                               FROM         DELPHI_OBLIGATION
                                                               GROUP BY   n_delphi_obligation_id
                                                          ) e
                                                      WHERE                b.n_delphi_obligation_id =a.n_delphi_obligation_id(+)
                                                     AND b.n_delphi_obligation_id =c.n_delphi_obligation_id(+)
                                                     AND b.n_delphi_obligation_id =d.n_delphi_obligation_id(+)
                                                     AND b.n_delphi_obligation_id =e.n_delphi_obligation_id(+)
                                                     ORDER BY            b.n_line_number,b.n_shipment_number,  b.n_distribution_number
                                                   ) T1,
                                                   (
                                                       SELECT
                                                                           line_num as line_number,
                                                                           shipment_number,
                                                                           distribution_num as distribution_number,
                                                                           SUM(NVL( quantity_ordered - QUANTITY_CANCELLED,0)) as Delphi_Obligated_Amount,
                                                                           -- sum(nvl(net_qty_ordered - quantity_ordered,0)) as Delphi_Obligated_Amount,
                                                                           SUM(NVL(quantity_billed,0)) as Delphi_paid_amount,
                                                                           SUM(NVL(net_qty_ordered - quantity_billed,0)) as Delphi_Balance
                                                       FROM            delphi_po
                                                       GROUP BY     line_num,shipment_number, distribution_num
                                                       ORDER BY     line_number, shipment_number, distribution_number
                                                   ) T2
                                                        WHERE               T1.line_number = T2.line_number
                                                        AND                    T1.shipment_number = T2.shipment_number
                                                        AND                    T1.distribution_number = T2.distribution_number
                                                        AND                    (T2.Delphi_Balance - T1.KITT_BALANCE) = 0
                                                        AND       T1.C_RECONCILIATION_STATUS   IN ('Acknowledge','Research');






/****************************************************************************************************************
*****************************************************************************************************************
*****************************************************************************************************************/

BEGIN

     FOR l_quantity IN csr_quantity LOOP

             IF (nvl(l_quantity.Delphi_Bal,0) - nvl(l_quantity.KITT_Bal,0)) <> 0 and  (upper(l_quantity.C_RECONCILIATION_STATUS)  NOT IN ('ACKNOWLEDGE','RESEARCH') or l_quantity.C_RECONCILIATION_STATUS is null)  THEN

                         UPDATE DELPHI_OBLIGATION SET C_RECONCILIATION_STATUS = 'Acknowledge'
                         WHERE n_delphi_obligation_id = l_quantity.n_delphi_obligation_id;
             END IF ;


        commit;
    END LOOP;

     FOR n_quantity IN csr_tquantity LOOP


            IF     (nvl(n_quantity.Delphi_Bal,0) - nvl(n_quantity.KITT_Bal,0)) = 0 and    (upper(n_quantity.C_RECONCILIATION_STATUS)   IN ('ACKNOWLEDGE','RESEARCH') or n_quantity.C_RECONCILIATION_STATUS is null)  THEN

                             UPDATE DELPHI_OBLIGATION SET C_RECONCILIATION_STATUS = 'Resolved'
                             WHERE n_delphi_obligation_id = n_quantity.n_delphi_obligation_id;
         END IF;

        commit;
    END LOOP;

      dbms_output.put_line('Successfully.');

 EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       Rollback;
       PK_INVOICE_LOADING .INVOICE_SEND_SUPPORT_EMAIL ( null, null, 'RECONCILIATION', 'Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.');
       dbms_output.put_line( 'Error:'||to_char(SQLCODE) ||'-'||SQLERRM||'.');

END PMO_RECONCILIATION;
/
