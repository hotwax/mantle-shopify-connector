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
            <#if queryParams.fromDate?has_content && !queryParams.thruDate?has_content>
                <#assign filterQuery = "created_at:>'${queryParams.fromDate}'"/>
            </#if>
            <#if queryParams.thruDate?has_content && !queryParams.fromDate?has_content>
                <#assign filterQuery = "created_at:<'${queryParams.thruDate}'"/>
            </#if>
            <#if queryParams.fromDate?has_content && queryParams.thruDate?has_content>
                <#assign filterQuery = "created_at:>'${queryParams.fromDate}' AND created_at:<'${queryParams.thruDate}'"/>
            </#if>

            query {
              orders(first: 50<#if cursor?has_content>, after: "${cursor}"</#if><#if filterQuery?has_content>, query: "${filterQuery}"</#if>) {
                pageInfo {
                  hasNextPage
                  endCursor
                  startCursor
                }
                edges {
                  node {
                    legacyResourceId
                    id
                    name
                    tags
                           totalPriceSet {
                             shopMoney {
                               amount
                               currencyCode
                             }
                           }
                           sourceName
                           statusPageUrl
                           shippingAddress {
                               name
                               address1
                               address2
                               city
                               country
                               zip
                               provinceCode
                               countryCodeV2
                               latitude
                               longitude
                               phone
                           }
                           billingAddress {
                             firstName
                             lastName
                             phone
                             address1
                             address2
                             longitude
                             latitude
                             city
                             province
                             country
                             zip
                             countryCode
                           }
                           phone
                           email
                           displayFulfillmentStatus
                           retailLocation {
                             id
                             legacyResourceId
                           }
                           customer {
                             legacyResourceId
                             id
                             firstName
                             lastName
                           }
                           customAttributes {
                               key
                               value
                           }
                           note
                           createdAt
                           cancelledAt
                           closedAt
                           currencyCode
                           presentmentCurrencyCode
                               transactions{
                                       kind
                                       status
                                       gateway
                                       id
                                       paymentDetails{
                                           ... on CardPaymentDetails {
                                             company
                                           }
                                       }
                                       amountSet{
                                           presentmentMoney{
                                               amount
                                           }
                                       }
                                       receiptJson
                                       settlementCurrency
                                       order{
                                           id
                                       }
                                       parentTransaction{
                                           id
                                           paymentDetails{
                                               ... on CardPaymentDetails {
                                             company
                                           }
                                           }
                                       }
                                       }
                  }
                }
            }}
            </@compress>
