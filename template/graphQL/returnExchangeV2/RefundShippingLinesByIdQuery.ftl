<#ftl output_format="HTML">
<@compress single_line=true>
query {
    refund(id: "${shopifyRefundId}") {
        id
        refundShippingLines (first : 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
            edges {
                node{
                    id
                    subtotalAmountSet{
                        presentmentMoney{
                            currencyCode
                            amount
                        }
                        shopMoney{
                            currencyCode
                            amount
                        }
                    }
                    taxAmountSet{
                        presentmentMoney{
                            currencyCode
                            amount
                        }
                        shopMoney{
                            currencyCode
                            amount
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
