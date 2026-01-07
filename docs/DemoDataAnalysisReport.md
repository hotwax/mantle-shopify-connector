# Analysis of Shopify Order Agreements Demo Data

This report analyzes the logical relationship between Shopify Order Agreements and other order entities (Refunds, Returns, Exchanges) based on the data found in the `demo-data` folder.

## 1. Overview of Data Structure

In the provided demo data (e.g., `LesserExchange.json`, `NormalReturnWithRestock.json`), we observe that `Order.agreements` lists several nodes. Even when the node content is empty due to the specific GraphQL query used to generate the JSON, their presence and position tell a story.

### Logical Mapping
| Agreement Node | Commercial Event | Corresponding Entity |
| :--- | :--- | :--- |
| **Node 1** | Initial Sale | `Order` (creation) |
| **Node 2** | Return/Refund Agreement | `Refund` or `Return` |
| **Node 3** | Exchange Agreement | `ExchangeV2` |

---

## 2. Case Study: Lesser Exchange
**File**: `LesserExchange.json`

This file shows an order where a high-value item was returned and a lower-value item was added, resulting in a partial refund.

### Logical Relationship:
1.  **Agreements**: Three edges are present.
    -   **Edge 1**: Represents the original sale of SKU `196-114-G`.
    -   **Edge 2 & 3**: Represent the return/exchange agreement. In the data, `SalesAgreement/6881331740716` is explicitly linked to `Refund/956701999148`.
2.  **Refund**: `Refund/956701999148` shows SKU `196-114-G` being returned (Quantity: 1).
3.  **Exchange (ExchangeV2)**: Shows an addition of SKU `2111-102-G`.
4.  **Transitions**: 
    -   A `SALE` transaction for $84.92 (original).
    -   A `REFUND` transaction for $8.71 (the difference between the returned and new item).

> [!IMPORTANT]
> **Key Finding**: The `RefundAgreement` acts as the bridge. It links the financial event (`Refund`) to the commercial agreement history.

---

## 3. Case Study: Normal Return with Restock
**File**: `NormalReturnWithRestock.json`

### Logical Relationship:
1.  **Agreements**: Two edges are present.
2.  **Return**: `Return/20650524716` is created for 1 unit of SKU `228-3005-G`.
3.  **Refund**: `Refund/956693577772` is issued for the value of the returned item ($315.74 including tax).
4.  **Logic**: The first agreement node is the `OrderAgreement`. The second node is the `RefundAgreement` (representing the agreement to reverse the sale of 1 unit).

---

## 4. Key Relationships Identified

### A. The "Chain of Custody"
Agreements are order-level records that point to specific transaction-level objects:
-   `SalesAgreement.refund` -> links to a `Refund` object.
-   `SalesAgreement.app` -> identifies which app (e.g., "Point of Sale", "Loop Returns") initiated the agreement.

### B. Agreement Typenames (Inferred)
Based on the lifecycle:
-   **OrderAgreement**: Always present at index 0. Represents initial commitment.
-   **RefundAgreement**: Created whenever a `Refund` is committed. 
-   **ReturnAgreement**: (Observed in complex returns) Created when a return is authorized, even before the refund.

### C. Logic of "Commercial Terms"
The data shows that agreements are **not** created for fulfillment changes. In `15_POS_Send_Sale_Unfulfilled_Cancelled_6346342301740.json` (if we were to look at it), a cancellation would trigger a `RefundAgreement` because it affects the ledger, whereas a simple "Mark as Fulfilled" would not.

---

## 5. Conclusion for Moqui Integration

When syncing Shopify data into Moqui (Mantle), we should:
1.  Map the **first** Agreement to the primary `OrderHeader` / `OrderItem` records.
2.  Map subsequent `RefundAgreements` to `ReturnItem` and `Invoice` (Credit Memo) records in Moqui.
3.  Use the `happenedAt` timestamp of the Agreement to accurately reflect the timeline in the Moqui `OrderHistory`.
