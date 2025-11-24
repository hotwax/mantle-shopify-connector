<#ftl output_format="HTML">
<@compress single_line=true>
query getCustomer($query: String!) {
    customers(first: 1, query: $query) {
        edges {
            node {
                id
                tags
                email
                phone
                firstName
            }
        }
    }
}
</@compress>