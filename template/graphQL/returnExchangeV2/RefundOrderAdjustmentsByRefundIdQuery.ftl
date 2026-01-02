<#ftl output_format="HTML">
<@compress single_line=true>
query {
    refund(id: "${shopifyRefundId}") {
        id
        orderAdjustments (first: 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
            edges {
                node {
                    id
                    amountSet {
                        presentmentMoney {
                            amount
                            currencyCode
                        }
                    }
                }
            }
            pageInfo {
                hasNextPage
                endCursor
            }
        }
    }
}
</@compress>
