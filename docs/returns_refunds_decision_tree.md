# Decision Tree: Shopify Returns & Refunds Integration

This document defines the logic used by the `create#ShopifyRefunds` service to classify Shopify data into business scenarios and attribute them correctly in Moqui/OMS.

## The Logic Flow

```mermaid
graph TD
    Start[Shopify Data Received] --> L0{Level 0: Global Check}
    
    L0 -->|Orphan?| Scenario10[Scenario 10: Orphan Return]
    Scenario10 --> Exit[EXIT]
    
    L0 -->|Order Exists| L1{Level 1: Intent Check}
    
    L1 -->|No Refund Line Items| L1_Sub{Appeasement / Shipping?}
    L1_Sub -->|Transactions| Scenario5[Scenario 5: Pure Appeasement]
    L1_Sub -->|Shipping Lines| Scenario8[Scenario 8: Shipping Only]
    L1_Sub -->|None| Exit
    Scenario5 --> Exit
    Scenario8 --> Exit

    L1 -->|Has Refund Line Items| L2{Level 2: Item Type Check}
    
    L2 -->|isGiftCard=True| Scenario9[Scenario 9: Gift Card Return]
    Scenario9 --> Exit
    
    L2 -->|isGiftCard=False| L3{Level 3: Compute Exchange?}
    L3 -->|isExchange=True| Scenario11[Scenario 11: Exchange]
    Scenario11 --> ExchangeExit[Process Exchange & EXIT]

    L3 -->|isExchange=False| L4{Level 4: Run Sieve}
    L4 -->|toCancel > 0| Scenario3[Scenario 3: Cancel Unfulfilled]
    Scenario3 --> SieveRemainder{Remaining Qty?}
    
    SieveRemainder -->|Yes| L5[Level 5: Return Refinement]
    SieveRemainder -->|No| Exit
    L4 -->|toReturn > 0| L5
    
    L5 -->|restockType=RETURN| Scenario1[Scenario 1: Normal Return]
    L5 -->|restockType=NO_RESTOCK| L5_Sub{Location Set?}
    L5_Sub -->|No| Scenario7[Scenario 7: Lost in Shipment]
    L5_Sub -->|Yes| Scenario2[Scenario 2: Refund No Restock]
    
    Scenario1 --> Exit
    Scenario7 --> Exit
    Scenario2 --> Exit
```

---

## 1. Primary Classification (Layered Execution)

### Level 0: Global Perimeter
- **Check**: Does the Order ID exist in Moqui?
- **Computation**: Database lookup by `externalId`.
- **Exit Path**: If false, immediately drop into **Scenario 10 (Orphan)**.

### Level 1: Intent Classification (Root Level)
- **Check**: Are there `refundLineItems`?
- **Computation**: Count of items in the refund object.
- **Exit Path (No Items)**:
    - If `transactions` exist -> **Scenario 5 (Appeasement)**.
    - If `refundShippingLines` exist -> **Scenario 8 (Shipping Refund)**.
    - Otherwise -> **EXIT** (Metadata/Zero-Value Update).

### Level 2: Item Type Check (isGiftCard?)
- **Lazy Computation**: Performed contextually for the line item.
- **Check**: `lineItem.isGiftCard == true`.
- **Exit Path**: If true, handle as **Scenario 9 (Gift Card Return)** and **EXIT**. This bypasses physical inventory and exchange logic.

### Level 3: Actionable Context (Compute Exchange?)
- **Check**: Is this a physical exchange session?
- **Computation**: Check Native `exchangeV2s` OR Return `exchangeLineItems` OR Loop App Agreement.
- **Exit Path**: If `isExchange` is True, perform exchange-specific ledger allocation and **EXIT**.

---

## 2. The Sieve (Level 4: Attribution)

Performed only if `isGiftCard` is False AND `isExchange` is False.

- **Check**: Distribute `quantity` based on Moqui Physical State.
- **Computation**: 
    - `toCancel = min(qty, moquiApproved)`
    - `toReturn = min(qty - toCancel, moquiShipped)`
- **Exit Path**: If `toCancel` exists, process cancel. If `toReturn > 0`, proceed to Level 5.

---

## 3. Return Refinement (Level 5: Shopify Flags)

Performed only for the physical `toReturn` portion.

- **Check**: What is the Shopify intent for the shipped item?
- **Scenario 1**: `restockType == RETURN` -> Standard Return.
- **Scenario 7**: `restockType == NO_RESTOCK` AND `location == null` -> Lost in Shipment Appeasement.
- **Scenario 2**: `restockType == NO_RESTOCK` AND `location != null` -> Damaged/Field Scrap.

---

## 4. Post-Processing Hooks (Parallel)

These logic blocks run after the primary scenario is decided, before final exit.

- **Scenario 6 (Loop)**: If Agreement App is "Loop", override the return source/channel.

---

## 4. Calculated Outputs

| Field | Source / Formula | Use Case |
| :--- | :--- | :--- |
| **totalReturnedAmount** | `subtotal + tax + adjustments` | Ledger balancing. |
| **exchangeCredit** | `totalReturnedAmount - cashRefunded` | Determining how much value was "swapped". |
| **A-Refund-Amt** | `refund.transactions.amount` | Actual cash impact. |
