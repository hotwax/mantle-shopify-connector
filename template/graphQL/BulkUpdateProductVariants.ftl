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
    mutation {
        bulkOperationRunMutation(
            mutation: "mutation call($input: ProductVariantInput!) {
                productVariantUpdate(input: $input) {
                    productVariant {
                        id
                        <#if namespaces?has_content>
                            <#assign namespaceList = StringUtil.split(namespaces, ",")!/>
                            <#list namespaceList as namespace>
                                metafield${namespace_index+1}:metafields(namespace:\"${namespace}\" first:10) {
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
                    userErrors {
                        message
                        field
                    }
                }
            }",
            stagedUploadPath: "${stagedUploadPath}") {
                bulkOperation {
                id
                url
                status
            }
            userErrors {
                message
                field
            }
        }
    }
</@compress>