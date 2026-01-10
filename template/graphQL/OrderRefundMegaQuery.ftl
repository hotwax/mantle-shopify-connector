<#ftl output_format="HTML">
<@compress single_line=true>
query GetOrderRefundDetails($shopifyOrderId: ID!) {
    order(id: $shopifyOrderId) {
        id
        name
        updatedAt
        cancelledAt
        customer {
            id
            firstName
            lastName
        }
        refunds {
            id
            createdAt
            note
            refundLineItems(first: 20) {
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
                            discountAllocations {
                                allocatedAmountSet {
                                    presentmentMoney {
                                        amount
                                        currencyCode
                                    }
                                    shopMoney {
                                        amount
                                        currencyCode
                                    }
                                }
                            }
                            taxLines {
                                priceSet {
                                    presentmentMoney {
                                        amount
                                        currencyCode
                                    }
                                    shopMoney {
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
                        priceSet {
                            presentmentMoney {
                                amount
                                currencyCode
                            }
                            shopMoney {
                                amount
                                currencyCode
                            }
                        }
                        restockType
                        quantity
                        subtotalSet {
                            presentmentMoney {
                                amount
                                currencyCode
                            }
                        }
                        totalTaxSet {
                            presentmentMoney {
                                amount
                                currencyCode
                            }
                            shopMoney {
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
            refundShippingLines(first: 20) {
                edges {
                    node {
                        id
                        subtotalAmountSet {
                            presentmentMoney {
                                currencyCode
                                amount
                            }
                            shopMoney {
                                currencyCode
                                amount
                            }
                        }
                        taxAmountSet {
                            presentmentMoney {
                                currencyCode
                                amount
                            }
                            shopMoney {
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
            transactions(first: 20) {
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
            orderAdjustments(first: 20) {
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
            return {
                id
                name
                status
                returnLineItems (first: 20) {
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
                        endCursor
                        hasNextPage
                    }
                }
                exchangeLineItems(first: 20) {
                    edges {
                        node {
                            id
                        }
                    }
                }
            }
        }
        refundAgreements: agreements(first: 20) {
            edges {
                node {
                    __typename
                    ... on RefundAgreement {
                        id
                        app {
                            id
                            title
                        }
                        refund {
                            id
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