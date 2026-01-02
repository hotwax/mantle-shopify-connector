<#ftl output_format="HTML">
<@compress single_line=true>
query {
    refund(id: "${shopifyRefundId}") {
        id
        refundLineItems (first : 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
            edges {
                node {
                    id
                    lineItem {
                        id
                        sku
                        isGiftCard
                        quantity
                        unfulfilledQuantity
                        variant {
                            id
                        }
                        discountAllocations{
                            allocatedAmountSet{
                                presentmentMoney{
                                    amount
                                    currencyCode
                                }
                                shopMoney{
                                    amount
                                    currencyCode
                                }
                            }
                        }
                        taxLines{
                            priceSet{
                                presentmentMoney{
                                    amount
                                    currencyCode
                                }
                                shopMoney{
                                    amount
                                    currencyCode
                                }
                            }
                            rate
                            title
                        }
                    }
                    location {
                        id
                    }
                    priceSet{
                        presentmentMoney{
                            amount
                            currencyCode
                        }
                        shopMoney{
                            amount
                            currencyCode
                        }
                    }
                    restockType
                    quantity
                    subtotalSet{
                        presentmentMoney{
                            amount
                            currencyCode
                        }
                    }
                    totalTaxSet{
                        presentmentMoney{
                            amount
                            currencyCode
                        },
                        shopMoney{
                            currencyCode
                            amount
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
