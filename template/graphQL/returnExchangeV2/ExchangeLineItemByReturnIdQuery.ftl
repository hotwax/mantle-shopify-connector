<#ftl output_format="HTML">
<@compress single_line=true>
query{
    return(id: "${returnId}"){
        id
        exchangeLineItems (first: 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
            edges{
                node{
                    id
                }
            }
            pageInfo{
                endCursor
                hasNextPage
            }
        }
    }
}
</@compress>
