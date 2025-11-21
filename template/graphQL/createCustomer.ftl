<#ftl output_format="HTML">
<@compress single_line=true>
mutation createCustomer($input: CustomerInput!) {
    customerCreate(input: $input) {
        customer {
            id
        }
        userErrors {
            field
            message
        }
    }
}
</@compress>
