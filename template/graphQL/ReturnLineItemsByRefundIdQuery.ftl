<#ftl output_format="HTML">
<@compress single_line=true>
query {
    refund(id: "${shopifyRefundId}") {
        id
        return {
            id
            returnLineItems (first : 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
                edges {
                    node {
                        ... on ReturnLineItem {
                            id
                            returnReason
                            quantity
                            withCodeDiscountedTotalPriceSet {
                                presentmentMoney {
                                    amount
                                    currencyCode
                                }
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
}
</@compress>