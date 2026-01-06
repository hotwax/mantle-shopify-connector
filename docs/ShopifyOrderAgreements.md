# Shopify Order Lifecycle and Sales Agreements

During the order lifecycle, key commercial events—order placement, edits, returns, or refunds—are recorded by Shopify as **Sales Agreements**. These agreements are stored under `Order.agreements` and represent contractual or financial changes to the order, providing a ledger-accurate timeline of how the sales contract evolved.

## 1. What are "Agreements" on an Order?

On a Shopify `Order`, the `agreements` field is a `SalesAgreementConnection`. Each node in this connection is a `SalesAgreement`, which can be one of several types:

- **OrderAgreement**: Created when the order is first placed.
- **OrderEditAgreement**: Created when commercial terms of the order are edited.
- **ReturnAgreement**: Created when a return is agreed upon.
- **RefundAgreement**: Created when a refund is issued.

### GraphQL Example
```graphql
order(id: "gid://shopify/Order/123456789") {
  agreements(first: 10) {
    edges {
      node {
        id
        happenedAt
        __typename  # OrderAgreement, OrderEditAgreement, ReturnAgreement, RefundAgreement
        sales(first: 10) { 
          # Details about line item sales, shipping sales, etc.
          __typename
          ... on ProductSale {
            quantity
            lineItem { title }
          }
        }
      }
    }
  }
}
```

> [!NOTE]
> **Analogy**:
> - **Order** is the current state.
> - **Agreements** is the history of major contract changes that led to that state.

---

## 2. Order Lifecycle Phases & Agreements

### Phase 1: Order Creation
**Event**: Customer completes checkout or merchant creates an order.
**Agreement**: `OrderAgreement`
- Records the initial agreement: products, quantities, prices, and shipping.
- Includes `ProductSale` entries for each line item and `ShippingLineSale` for shipping charges.

### Phase 2: Order Edited (Optional)
**Event**: Merchant edits the order (e.g., adding/removing items, changing quantity) using order editing features.
**Agreement**: `OrderEditAgreement`
- Each committed edit produces a new `OrderEditAgreement`.
- It records the *changes* to the commercial content (e.g., -2 of item X, +1 of item Y).
- **Crucial**: Adding tags, notes, or updating shipping addresses (without changing commercial terms) does **not** create an agreement.

### Phase 3: Return Agreed (Optional)
**Event**: Customer and merchant agree to return items (via Admin UI or returns apps).
**Agreement**: `ReturnAgreement`
- Records the contractual impact of the return at a specific point in time.
- Sales on a `ReturnAgreement` use negative quantities/amounts to reflect the impact on the ledger.
- Note: The logistical side (reverse fulfillments) is separate from the `ReturnAgreement`.

### Phase 4: Refund Issued (Optional)
**Event**: Merchant issues a refund (often tied to a return, but could be an appeasement).
**Agreement**: `RefundAgreement`
- Records the agreement to refund a specific amount.
- Tied to a `Refund` object which contains technical payment gateway details and transactions.
- Shows how the refund affected the financial ledger.

---

## 3. What Does NOT Create an Agreement?

Agreements are only created for events that affect the **sales contract or financial ledger**. The following updates generally do not create new entries in `Order.agreements`:

- Adding or removing **tags**.
- Changing the **order note**.
- Updating **shipping or billing addresses** (unless linked to a commercial edit).
- Changing **fulfillment status** (tracked via `FulfillmentOrder` and events).
- Updating **metafields** or internal metadata.

---

## 4. Timeline of Commercial Events

Agreements provide a ledger-accurate, time-stamped record of the order's evolution. For example:

1. **OrderAgreement** (T1): Sale of 3 units of A, 2 units of B, shipping $5.
2. **OrderEditAgreement** (T2): Remove 1 unit of B, add 1 unit of C.
3. **ReturnAgreement** (T3): Return 1 unit of A.
4. **RefundAgreement** (T4): Refund $X for return of A.

---

## Summary

> Shopify records SalesAgreements in `order.agreements` at key commercial moments: `OrderAgreement` (creation), `OrderEditAgreement` (edits), `ReturnAgreement` (returns), and `RefundAgreement` (refunds). These form a timeline of the sales contract's evolution. Only updates affecting commercial terms or the financial ledger create agreements, not metadata changes like tags or notes.
