# Shopify Returns/Refunds Integration — Scenarios and Decision Data Elements

This document consolidates the handwritten notes into a single, implementation-oriented reference. It lists (A) business scenarios to detect and handle, and (B) the Shopify/OMS data elements used to classify scenarios and compute amounts.

---

## A) Business scenarios

### 1) Normal return with restock
**Intent:** A standard return where items will be restocked.

**Signals / conditions**
- `refund.return != null`
- `refund.refundLineItem.restockType = RETURN`

---

### 2) Refund with NO_RESTOCK (return exists, but no restock)
**Intent:** Return/refund exists but inventory is not restocked.

**Signals / conditions**
- `refund.return != null`
- `refund.refundLineItem.restockType = NO_RESTOCK`

---

### 3) Unfulfilled item refunded
**Intent:** Customer is refunded for items that were not fulfilled.

**Signals / conditions**
- `refund.return is null`
- `refund.refundLineItem exists`
- Compare **Shopify unfulfilled qty** vs **OMS approved qty** (notes indicate unfulfilled quantity is less than OMS approved quantity and approved–unfulfilled > 0)

---

### 4) Fulfilled item refunded
**Intent:** Refund for items that were fully fulfilled (no remaining unfulfilled quantity).

**Signals / conditions**
- `approvedQty (OMS) = 0`
- `unfulfilledQty (Shopify) = 0`

---

### 5) Pure appeasement
**Intent:** Money is refunded without item-level refund lines (customer appeasement).

**Signals / conditions**
- `refund.refundLineItems is NULL`

---

### 6) Return via Loop
**Intent:** Return initiated through Loop. Return may exist even when refund is not yet present.

**Signals / conditions**
- Identify by refund agreement app title: `refundAgreements.app.title = "LOOP"`

**Operational notes (from handwritten flow)**
- Return created on Loop → return created on Shopify (in-progress/completed)
- Refund agreement gets created
- Return object may have **return line items** while **refund object is empty**
- Return line items indicate which order line item is being returned

---

### 7) Appeasement — Lost in shipment
**Intent:** CSR issues refund/return without restocking; often location not set.

**Signals / conditions**
- `refund.return != null` (notes indicate “not mandatory”, but included as a common signal)
- `refund.refundLineItem.restockType = "NO_RESTOCK"`
- `refund.refundLineItem.location` is empty

**Operational notes**
- CSR creates return + refund amount, but items are not restocked

---

### 8) Refund with shipping amount
**Intent:** Refund includes shipping charges (and potentially shipping tax).

**Signals / conditions**
- `refund.refundShippingLines` exists

---

### 9) Custom gift card return
**Intent:** Gift card item returned; often missing variant/sku.

**Signals / conditions**
- No variant on Shopify
- `lineItem.isGiftCard = true`
- `variantId` and `sku` are empty

---

### 10) Orphan return
**Intent:** Refund/return exists in Shopify, but OMS order does not exist.

**Signals / conditions**
- Check `OrderHeader` in OMS by **Shopify order id**
- If OMS order does not exist → orphan return

**Operational notes**
- Because OMS order doesn’t exist, payload must be prepared using Shopify data:
  - `itemPrice`
  - `itemAdjustment`

---

### 11) Exchanges (for exchange credit calculation)
**Intent:** Identify exchange-related returns and compute exchange credit.

**Signals / conditions**
- To identify exchanges: `refund.return.exchangeLineItem` exists

---

## B) Data elements used in the decision process

This section lists the exact data elements used to classify scenarios and compute amounts.

---

### 1) Presence/shape checks (classification signals)
- `refund.return` (exists vs null)
- `refund.return.exchangeLineItem` (exchange identification)
- `refund.return.returnLineItem` (return line items present)
- `refund.refundLineItems` (null → pure appeasement)
- `refundAgreements.app.title` (Loop detection)

---

### 2) Item-level attributes (return vs no-restock vs special handling)
- `refund.refundLineItem.restockType` (RETURN vs NO_RESTOCK)
- `refund.refundLineItem.location` (empty used in “lost in shipment” pattern)

Gift card identification from line item:
- `lineItem.isGiftCard`
- `lineItem.variantId`
- `lineItem.sku`

---

### 3) Quantity-based decision inputs (refund vs cancel vs fulfilled/unfulfilled reasoning)
- `refund.refundLineItem.quantity`
- `refund.refundLineItem.lineItem.unfulfilledQty` (Shopify)
- `approvedQty` (OMS) for comparison against Shopify unfulfilledQty

---

### 4) Money fields used to compute prices/amounts

From `refund.refundLineItems[].lineItem`:
- `subtotalAmountSet.presentmentMoney.amount`
- `totalTaxSet.presentmentMoney.amount`
- `taxLines[].presentmentMoney.amount`
- `discountAllocation[].presentmentMoney.amount`

From refund payments (actual refunded amount):
- `refund.transactions[ kind = Refund ].amountSet.presentmentMoney.amount`

From shipping refunds:
- `refund.refundShippingLines[].subtotalAmountSet`
- `refund.refundShippingLines[].taxAmountSet`

---

### 5) Derived/calculated fields you want

#### 5.1 `totalReturnedAmount`
**Requirement:** “Return ke andar ek field chahiye: total returned amount.”

**Composed from (as per notes):**
- item value (`itemPrice`)
- item adjustments (`itemAdj`)
- shipping refund (`shippingRefund`)


#### 5.2 `itemPrice`
**Formula (as written in notes):**
- `itemPrice = subtotalAmountSet + totalTaxSet`


#### 5.3 `exchangeCredit`
**Only for exchange detection cases.**

**Formula (as written in notes):**
- `exchangeCredit = totalReturnedAmount - ARefundAmt`

Where:
- `ARefundAmt` is derived from refund transactions (kind=Refund)

**Refund amount components noted:**
- `itemPrice`
- `itemAdj`
- `shippingRefund`

---

## C) Quick reference summary

### Scenario → key signals
- **Return + restock:** `return != null` AND `restockType=RETURN`
- **Return + no restock:** `return != null` AND `restockType=NO_RESTOCK`
- **Pure appeasement:** `refundLineItems is NULL`
- **Loop return:** `refundAgreements.app.title = LOOP`
- **Lost in shipment appeasement:** `restockType=NO_RESTOCK` AND `location empty`
- **Shipping refund included:** `refundShippingLines exists`
- **Gift card return:** `isGiftCard=true` AND `sku/variantId empty`
- **Orphan return:** OMS order not found by Shopify order id
- **Exchange:** `return.exchangeLineItem exists` → compute `exchangeCredit`

---

## D) Notes / open items
- The notes refer to `itemAdj` (item adjustments) but do not fully specify its exact Shopify source path in the handwritten pages. When implementing, ensure the adjustment definition is finalized (tax lines vs discount allocations vs other adjustments) so totals reconcile with transactions.

