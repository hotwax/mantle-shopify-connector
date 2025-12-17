<#ftl output_format="HTML">
<@compress single_line=true>
mutation tagsRemove($id: ID!, $tags: [String!]!) {
    tagsRemove(id: $id, tags: $tags) {
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
