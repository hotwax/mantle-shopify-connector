<#ftl output_format="HTML">
<@compress single_line=true>
mutation tagsAdd($id: ID!, $tags: [String!]!) {
    tagsAdd(id: $id, tags: $tags) {
        node {
            id
            ... on Customer {
                tags
            }
        }
        userErrors {
            field
            message
        }
    }
}
</@compress>
