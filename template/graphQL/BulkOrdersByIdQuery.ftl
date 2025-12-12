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
    <#-- Optional explicit filter condition -->
    <#if queryParams.filterCondition?has_content>
      <#assign filterCondition = queryParams.filterCondition/>
    <#else>
      <#assign filterCondition = "">
    </#if>

    <#-- Date label defaults -->
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
    query: """{
      orders <#if filterQuery?has_content> (query: "${filterQuery}")</#if> {
        edges {
          node {
            legacyResourceId
            id
            name
            tags

            totalPriceSet {
              shopMoney { amount currencyCode }
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

            customAttributes { key value }
            note
            createdAt
            cancelledAt
            closedAt
            currencyCode
            presentmentCurrencyCode

            lineItems {
              edges {
                node {
                  id
                  quantity

                  originalUnitPriceSet {
                    shopMoney { amount }
                  }

                  customAttributes { key value }

                  title
                  name

                  variant {
                    legacyResourceId
                    title
                  }

                  discountAllocations {
                    allocatedAmountSet { shopMoney { amount } }
                    discountApplication {
                      __typename
                      ... on DiscountCodeApplication { code }
                    }
                  }

                  taxLines {
                    title
                    rate
                    priceSet { shopMoney { amount } }
                  }

                  requiresShipping
                  nonFulfillableQuantity
                  unfulfilledQuantity
                  isGiftCard
                }
              }
            }

            transactions {
              kind
              status
              gateway
              id

              paymentDetails {
                ... on CardPaymentDetails { company }
              }

              amountSet {
                presentmentMoney { amount }
              }

              receiptJson
              settlementCurrency

              order { id }

              parentTransaction {
                id
                paymentDetails {
                  ... on CardPaymentDetails { company }
                }
              }
            }

            shippingLines {
              edges {
                node {
                  title
                  originalPriceSet {
                    presentmentMoney { amount currencyCode }
                  }

                  discountAllocations {
                    allocatedAmountSet {
                      presentmentMoney { amount currencyCode }
                    }
                    discountApplication {
                      ... on DiscountCodeApplication {
                        code
                        targetType
                        value {
                          ... on PricingPercentageValue { percentage }
                        }
                      }
                    }
                  }
                  taxLines {
                    title
                    priceSet {
                      presentmentMoney { amount currencyCode }
                    }
                  }
                }
              }
            }

          }
        }
      }
    }""" ) {
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