<#ftl output_format="HTML">
<@compress single_line=true>
query {
    order(id: "gid://shopify/Order/${shopifyOrderId}") {
        id
        agreements (first: 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
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
