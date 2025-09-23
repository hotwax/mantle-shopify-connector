<#ftl output_format="HTML">
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
        <#if queryParams.namespace?has_content>
            <#assign namespace = queryParams.namespace/>
        </#if>
        <#if queryParams.filterQuery?has_content>
            <#assign filterQuery = queryParams.filterQuery/>
        <#else>
            <#if queryParams.filterCondition?has_content>
                <#assign filterCondition = queryParams.filterCondition/>
            <#else>
                <#assign filterCondition = "">
            </#if>
            <#if queryParams.fromDateLabel?has_content>
                <#assign fromDateLabel = queryParams.fromDateLabel/>
            <#else>
                <#assign fromDateLabel = "updated_at"/>
            </#if>
            <#if queryParams.thruDateLabel?has_content>
                <#assign thruDateLabel = queryParams.thruDateLabel/>
            <#else>
                <#assign thruDateLabel = "updated_at"/>
            </#if>
        <#-- Build date filters -->
            <#assign dateFilters = "">
            <#if queryParams.fromDate?has_content>
                <#assign dateFilters = dateFilters + "${fromDateLabel}:>'${queryParams.fromDate}'"/>
            </#if>
            <#if queryParams.thruDate?has_content>
                <#if dateFilters?has_content>
                    <#assign dateFilters = dateFilters + " AND "/>
                </#if>
                <#assign dateFilters = dateFilters + "${thruDateLabel}:<'${queryParams.thruDate}'"/>
            </#if>

        <#-- Combine filterCondition and dateFilters -->
            <#if filterCondition?has_content && dateFilters?has_content>
                <#assign filterQuery = "${filterCondition} AND ${dateFilters}"/>
            <#elseif filterCondition?has_content>
                <#assign filterQuery = filterCondition/>
            <#elseif dateFilters?has_content>
                <#assign filterQuery = dateFilters/>
            <#else>
                <#assign filterQuery = "">
            </#if>
        </#if>
    </#if>
    mutation {
        bulkOperationRunQuery(
            query: """ {
                products <#if filterQuery?has_content>(query:"${filterQuery}")</#if> {
                    edges {
                        node {
                            id
                            handle
                            title
                            isGiftCard
                            productType
                            vendor
                            category {
                                id
                                name
                                fullName
                            }
                            hasVariantsThatRequiresComponents
                            featuredMedia {
                                mediaContentType
                                    preview {
                                        image {
                                            url
                                        }
                                    }
                                }
                            options {
                                id
                                name
                                position
                                optionValues {
                                    id
                                    name
                                }
                            }
                            tags
                            variants {
                                edges {
                                    node {
                                        id
                                        title
                                        sku
                                        barcode
                                        product {
                                            id
                                            handle
                                            title
                                            isGiftCard
                                            productType
                                            vendor
                                        }
                                        price
                                        compareAtPrice
                                        position
                                        requiresComponents
                                        image {
                                            url
                                        }
                                        selectedOptions {
                                            name
                                            value
                                        }
                                        inventoryItem {
                                            id
                                            requiresShipping
                                            measurement {
                                                weight {
                                                    unit
                                                    value
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            <#if namespace?has_content>
                                metafields (namespace:"${namespace}") {
                                edges {
                                    node {
                                        id
                                        key
                                        namespace
                                        value
                                        type
                                        reference {
                                            ... on Metaobject {
                                                id
                                                handle
                                                type
                                                fields {
                                                    key
                                                    value
                                                }
                                            }
                                        }
                                    }
                                }
                            </#if>
                        }
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