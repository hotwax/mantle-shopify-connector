<#ftl output_format="HTML">
<@compress single_line=true>
query {
    refund(id: "${shopifyRefundId}") {
        id
        transactions (first : 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
            edges {
                node {
                    id
                    parentTransaction {
                        id
                    }
                    status
                    amountSet {
                        presentmentMoney {
                            amount
                            currencyCode
                        }
                        shopMoney {
                            amount
                            currencyCode
                        }
                    }
                    kind
                    gateway
                    paymentDetails {
                        ... on CardPaymentDetails {
                            company
                        }
                    }
                }
            }
            pageInfo {
                endCursor
                hasNextPage
            }
        }
    }
}
</@compress>
