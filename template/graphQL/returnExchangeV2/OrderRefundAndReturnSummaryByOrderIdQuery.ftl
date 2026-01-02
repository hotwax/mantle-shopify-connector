<#ftl output_format="HTML">
<@compress single_line=true>
query {
    order(id: "gid://shopify/Order/${shopifyOrderId}") {
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
            return {
                id
                status
                name
            }
        }
    }
}
</@compress>
