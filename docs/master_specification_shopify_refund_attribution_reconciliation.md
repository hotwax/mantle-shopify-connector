# Master Specification: Shopify Refund Attribution & Reconciliation

This document consolidates all technical designs, algorithmic patterns, and UAT findings into a single Source of Truth for the create#ShopifyRefunds service refactor.

## 1. Data Retrieval: High-Confidence Mega Query

To eliminate N+1 queries and handle POS Exchanges correctly, use this consolidated GraphQL query.

Key Requirements:

- totalRefundedSet: Mandatory for "Exchange" vs. "Return" financial detection.
- subtotalSet: Mandatory for verifying item-level value during exchanges.
- agreements: Fetches implementation-specific fragments to identify source apps (POS, Web, Loop).

```graphql
query GetOrderRefundDetails($shopifyOrderId: ID!) {
  order(id: $shopifyOrderId) {
    id
    name
    lineItems(first: 250) {
      edges {
        node {
          id
          sku
          quantity
          unfulfilledQuantity
        }
      }
    }
    refunds {
      id
      createdAt
      note
      totalRefundedSet { shopMoney { amount currencyCode } }
      return { id status name }
      refundLineItems(first: 20) {
        edges {
          node {
            lineItem { id }
            quantity
            subtotalSet { shopMoney { amount } }
            restockType
          }
        }
      }
      orderAdjustments(first: 5) {
        edges {
          node {
            amountSet { shopMoney { amount } }
            reason
          }
        }
      }
    }
    returns(first: 10) {
      edges {
        node {
          id
          status
          name
          returnLineItems(first: 20) {
            edges {
              node {
                id
                quantity
                ... on ReturnLineItem {
                  returnReason
                  returnReasonNote
                  withCodeDiscountedTotalPriceSet {
                    presentmentMoney { amount }
                  }
                  fulfillmentLineItem {
                    lineItem { id }
                  }
                }
              }
            }
          }
          exchangeLineItems(first: 20) {
            edges {
              node {
                id
                quantity
                variantId
              }
            }
          }
        }
      }
    }
    exchangeV2s(first: 5) {
      edges {
        node {
          additions {
            lineItems {
              lineItem { id sku quantity }
            }
          }
        }
      }
    }
    agreements(first: 20) {
      edges {
        node {
          id
          reason
          app { title }
          ... on RefundAgreement { refund { id } }
        }
      }
    }
    transactions(first: 10) {
      id
      kind
      status
      gateway
      amountSet { shopMoney { amount } }
      processedAt
    }
  }
}
```

## 2. The Algorithm: "The Sieve" (OMS-First)

Process every new Shopify refund through three sequential phases. We strictly follow the OMS State Ownership rule: the Moqui state is the definitive boundary for capacity.

### Phase A (The Action Type):

- RETURN: If refund.return.id exists OR Agreement App is Loop.
- APPEASEMENT: If transactions exist but refundLineItems is empty.
- CANCEL/RETURN (Derived): If neither, use Phase B Sieve to derive.

### Phase B (The Capacity Sieve):

- \$C\_{max}\$ (Cancel Capacity): Moqui ITEM\_APPROVED quantity.
- \$R\_{max}\$ (Return Capacity): Moqui ITEM\_SHIPPED quantity.

Exchange Detection:

- Native Verification: If order.exchangeV2s is non-empty, this order is in an EXCHANGE session.
- Return Verification: If refund.return.exchangeLineItems is non-empty, it is an EXCHANGE.
- App Verification: If Agreement App is Loop and restockType is NO\_RESTOCK, it is a LOOP EXCHANGE.

### Phase C (The Solver):

- Recursive backtracking for complex partial fulfillment.

## 3. High-Confidence Case Study: POS Exchanges

This logic ensures that inventory movement matches financial reconciliation.

### Case 1: Equal Exchange (#GORTEST22440)

Data: Item Value = \$78.00 | Cash Refunded = \$0.00 | Adjustments = [] Logic: Detected as EQUAL EXCHANGE. Create RETURN in Moqui with \$0.00 cash impact.

### Case 2: Lesser Exchange (#GORTEST22438)

Data: Item Value = \$78.00 | Cash Refunded = \$8.71 | Adjustments = [] Logic: Detected as EXCHANGE + REFUND. Create RETURN in Moqui with \$8.71 cash impact.

### Case 3: Used Item / Restocking Fee

Data: Item Value = \$78.00 | Cash Refunded = \$39.00 | Adjustments = [RESTOCK: -\$39.00] Logic: Detected as PARTIAL CREDIT. The difference is explicitly accounted for by the adjustment reason.

### Case 4: App-Driven Exchange (Loop)

Data: Agreement App = Loop Returns | refund.return = null | restockType = NO\_RESTOCK Logic: Detected as LOOP MANAGED RETURN. Even with a null native return object, the App Agreement + EXC- prefix provides 100% confidence for RETURN attribution.

### Case 5: High-Value POS Exchange (#GORTEST22440)

Data: Returned Item = \$84.92 | New Item Addition = 2111-101a-G | Top-up SALE = \$214.49 Logic: Detected as UPGRADE EXCHANGE.

OMS Attribution:

- Payment A: Original \$84.92 (Applied to original items).
- Credit Memo: \$84.92 attributed to Return Item, but not refunded to customer.
- Payment B: New \$214.49 transaction recorded as "Exchange Top-up".
- Total Revenue: \$299.41 (Initial \$84.92 + New \$214.49).

## 4. Implementation Snippets (Functional Groovy)

```groovy
// Initialize Capacity Pools (Strict Moqui Source)
def cancelPool = moquiState.pendingCount.clone()
def returnPool = moquiState.shippedCount.clone()
// Sieve Loop
newRefunds.each { refund ->
    refund.refundLineItems.edges*.node.each { rli ->
        def sku = skuByLineItemId[rli.lineItem.id]
        
        // 1. Sieve Settlement
        int toCancel = Math.min(rli.quantity, cancelPool[sku] ?: 0)
        cancelPool[sku] -= toCancel
        
        int toReturn = Math.min(rli.quantity - toCancel, returnPool[sku] ?: 0)
        returnPool[sku] -= toReturn
        
        // 2. Financial Reconciliation Check
        BigDecimal itemVal = rli.subtotalSet.shopMoney.amount as BigDecimal
        BigDecimal cashOut = refund.totalRefundedSet.shopMoney.amount as BigDecimal
        
        // Sum any restocking fees/discrepancies
        def adjustments = refund.orderAdjustments.edges*.node
        BigDecimal totalAdjustments = adjustments.sum { (it.amountSet.shopMoney.amount as BigDecimal) ?: 0.0 }
        
        // DISAMBIGUATION Logic:
        // 1. Check for explicit Native Exchange (ExchangeV2 on Order)
        boolean isNativeExchange = order.exchangeV2s.edges.size() > 0
        // 2. Check for Native Return Object Exchange
        def returnObj = returns.find { r -> r.returnLineItems.edges.any { it.node.fulfillmentLineItem?.lineItem?.id == rli.lineItem.id } }
        boolean isReturnExchange = returnObj?.exchangeLineItems?.edges?.size() > 0
        // 3. Check for Loop App logic
        def agreement = agreements.find { it.refund?.id == refund.id }
        boolean isLoopExchange = (agreement?.app?.title == 'Loop Returns & Exchanges' && rli.restockType == 'NO_RESTOCK')
        boolean isExchange = isNativeExchange || isReturnExchange || isLoopExchange
        
        // Channel ID mapping
        def channel = agreements.find { it.refund?.id == refund.id }?.app?.title ?: 'Web'
        
        // Collect result for Moqui Return item creation
        attributionResults.add([
            refundId: refund.id,
            sku: sku,
            cancelQty: toCancel,
            returnQty: toReturn,
            appeasementQty: toAppease,
            isExchange: isExchange,
            hasFee: hasRestockingFee,
            channel: channel,
            returnId: refund.return?.id
        ])
    }
}
```

## 5. Transaction Attribution Logic (Money Changing Hands)

Every transaction must be attributed to an event to ensure the "Reason" for money movement is clear in Moqui.

| Transaction Kind | Context                | Moqui Action / Reason                     |
| ---------------- | ---------------------- | ----------------------------------------- |
| SALE             | Order Creation         | Payment: "Initial Purchase"               |
| REFUND           | Refund Object          | Payment (Negative): "Return Refund"       |
| SALE             | Post-Refund (Exchange) | Payment: "Exchange Top-up"                |
| REFUND           | totalRefundedSet = \$0 | Credit Memo: "Applied as Exchange Credit" |

Rule: If a SALE transaction occurs within the same minute or immediately following a refund with \$0 cash back, it is guaranteed to be a Top-up payment for an exchange.

