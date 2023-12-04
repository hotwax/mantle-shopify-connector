<#--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

<@compress single_line=true>
    <#if queryParams?has_content>
      <#if queryParams.filterQuery?has_content>
        <#assign filterQuery = queryParams.filterQuery/>
      <#else>
          <#if queryParams.fromDateLabel?has_content>
              <#assign fromDateLabel = queryParams.fromDateLabel/>
          <#else>
              <#assign fromDateLabel = "created_at"/>
          </#if>
          <#if queryParams.thruDateLabel?has_content>
              <#assign thruDateLabel = queryParams.thruDateLabel/>
          <#else>
              <#assign thruDateLabel = "created_at"/>
          </#if>
          <#if queryParams.fromDate?has_content && !queryParams.thruDate?has_content>
              <#assign filterQuery = "${fromDateLabel}:>'${queryParams.fromDate}'"/>
          </#if>
          <#if queryParams.thruDate?has_content && !queryParams.fromDate?has_content>
              <#assign filterQuery = "${thruDateLabel}:<'${queryParams.thruDate}'"/>
          </#if>
          <#if queryParams.fromDate?has_content && queryParams.thruDate?has_content>
              <#assign filterQuery = "${fromDateLabel}:>'${queryParams.fromDate}' AND ${thruDateLabel}:<'${queryParams.thruDate}'"/>
          </#if>
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