# Decision Tree: Shopify Returns & Refunds Refactored

This document defines the core logic for the `create#ShopifyRefunds` service, focusing on accurate inventory attribution and financial reconciliation.

## 1. The Decision Hierarchy

```mermaid
graph TD
    Start[Shopify Refund Received] --> L0{Level 0: Global Check}
    
    L0 -->|Order Missing| Scenario10[Scenario 10: Orphan Return]
    L0 -->|Order Exists| L1{Level 1: Refund Shape}
    
    L1 -->|No Item Lines| L1_Sub{Check Charges}
    L1_Sub -->|Transactions Only| Scenario5[Scenario 5: Pure Appeasement]
    L1_Sub -->|Shipping Lines| Scenario8[Scenario 8: Shipping Refund]
    
    L1 -->|Has Item Lines| Loop[FOR EACH refundLineItem]
    
    subgraph Item_Attribution [Item attribution & Context]
        Loop --> Sieve{Step A: The Sieve}
        Sieve -->|Moqui Approved| S_Cancel[Scenario 3: Cancel]
        Sieve -->|Moqui Shipped| S_Return[Return Context]
        
        S_Return --> StepB{Step B: Financial Context}
        StepB -->|isExchange?| X_Flag[Add Exchange Relationship]
        StepB -->|isGiftCard?| Scenario9[Scenario 9: Gift Card]
        
        S_Return --> StepC{Step C: Restock Intent}
        StepC -->|RETURN| Scenario1[Scenario 1: Normal Return]
        StepC -->|NO_RESTOCK + Location| Scenario2[Scenario 2: Damaged/Refuse]
        StepC -->|NO_RESTOCK + No Location| Scenario7[Scenario 7: Lost in Shipment]
    end

    Scenario1 --> Next[Next Item?]
    Scenario2 --> Next
    Scenario3 --> Next
    Scenario7 --> Next
    Scenario9 --> Next
    X_Flag --> Next
    
    Next -->|Yes| Loop
    Next -->|No| Recon[Level 2: Money Situation Reconciliation]
    Recon --> Exit[Update Moqui & EXIT]
```

---

## 2. Core Logic Definitions

### Level 0: Global Perimeter
- **Check**: Database lookup of `OrderHeader.externalId` using Shopify Order ID.
- **Outcome**: If missing, treat as an **Orphan Return (Scenario 10)**.

### Level 1: Refund Shape
- If `refundLineItems` is empty, determine if it's **Pure Appeasement (Scenario 5)** or a **Shipping Refund (Scenario 8)** based on transaction and shipping line presence.

---

## 3. Item-Level Attribution (Decoupled Sieve)

For every line item in the refund, we apply the following logic sequentially:

### Step A: The Physical Sieve (Capacity Attribution)
Based on Moqui's inventory state, we distribute the quantity:
1. **toCancel**: `min(qty, moquiApprovedPool)` -> **Cancel Unfulfilled (Scenario 3)**.
2. **toReturn**: `min(qty - toCancel, moquiShippedPool)` -> Proceed to Return Context.

### Step B: Financial Context (Overlays)
These flags qualify the return but do not change its physical status:
- **Exchange Relationship**: Identify if the item is part of an exchange session (Native V2, Return exchange items, or POS Temporal Salle).
- **Gift Card**: If `isGiftCard = true`, bypass physical inventory movement.

### Step C: Restock intent (Refinement)
For the `toReturn` portion, identify the inventory impact:
- **Scenario 1**: Standard Return (`RETURN`).
- **Scenario 7**: Lost in Shipment (`NO_RESTOCK` with no location set).
- **Scenario 2**: Damaged / Field Scrap (`NO_RESTOCK` with location set).

---

## 4. Money Situation Reconciliation (Level 2)

Final financial balancing for the entire refund:
1. **totalReturnedAmount**: The gross value of all returned/cancelled items + shipping refund.
2. **aRefundAmt**: The actual cash-out value from Shopify `transactions`.
3. **exchangeCredit**: `totalReturnedAmount - aRefundAmt`. This value represents the financial "swap" to be applied to new items or credit memos.

---

## 5. Channel Attribution (Metadata)
- **Origin**: Use `refundAgreement.app.title` (e.g., "Loop", "POS") as metadata to track the channel, without forking the primary logic.
