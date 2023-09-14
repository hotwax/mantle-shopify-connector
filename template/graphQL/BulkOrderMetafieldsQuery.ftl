<@compress single_line=true>
    <#if queryParams?has_content>
      <#if queryParams.filterQuery?has_content>
        <#assign filterQuery = queryParams.filterQuery/>
      <#else>
          <#assign filterQuery = "created_at:>${queryParams.fromDate!} AND created_at:<${queryParams.thruDate!}"/>
      </#if>
    </#if>

    mutation {
        bulkOperationRunQuery(
            query: """ {
                orders <#if filterQuery?has_content>(query:"${filterQuery}")</#if> {
                    edges {
                        node {
                            id
                            <#-- Added below check to request only specific metafields from Shopify based on given namespace list   -->
                            <#if queryParams?has_content && queryParams.namespaces?has_content>
                                <#assign namespaceList = queryParams.namespaces.split(",")!/>
                                <#list namespaceList as namespace>
                                   metafield${namespace_index + 1}: metafields (<#if namespace?has_content>namespace: "${namespace}"</#if>) {
                                       edges {
                                           node {
                                               id
                                               key
                                               namespace
                                               value
                                               type
                                           }
                                       }
                                   }
                                </#list>
                            </#if>
                        }
                    }
                }
            }
        """ ) {
            bulkOperation {
                id
                status
            }
            userErrors {
                field
                message
            }
        }
    }
</@compress>