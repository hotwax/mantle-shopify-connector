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
                        query {
                            node(id: "${shopifyOrderId}") {
                                id
                                ... on
                                Order {
                                   id
                                    name

                                          customer {
                                            id
                                            firstName
                                            lastName
                                          }

                                          originalTotalPriceSet {
                                            presentmentMoney {
                                              currencyCode
                                            }
                                          }
                                    exchangeV2s (first: 10<#if cursor?has_content>, after: "${cursor}"</#if>) {
                                        edges {
                                            node {
                                                id
                                                completedAt
                                                location {
                                                    id
                                                }
                                                additions {
                                                    totalPriceSet {
                                                        presentmentMoney {
                                                            amount
                                                            currencyCode
                                                        }
                                                    }
                                                    lineItems {
                                                        lineItem {
                                                            id
                                                            quantity
                                                            sku
                                                            variant{
                                                                id
                                                            }
                                                            variantTitle
                                                            isGiftCard
                                                            product {
                                                                id
                                                                title
                                                            }
                                                            originalUnitPriceSet {
                                                                presentmentMoney {
                                                                    amount
                                                                    currencyCode
                                                                }
                                                            }
                                                            originalTotalSet {
                                                                presentmentMoney {
                                                                    amount
                                                                    currencyCode
                                                                }
                                                            }
                                                            discountedUnitPriceSet {
                                                                presentmentMoney {
                                                                    amount
                                                                    currencyCode
                                                                }
                                                            }
                                                            discountedUnitPriceAfterAllDiscountsSet {
                                                                presentmentMoney {
                                                                    currencyCode
                                                                    amount
                                                                }
                                                            }
                                                            discountedTotalSet {
                                                                presentmentMoney {
                                                                    amount
                                                                    currencyCode
                                                                }
                                                            }
                                                            discountAllocations {
                                                                allocatedAmountSet {
                                                                    presentmentMoney {
                                                                        amount
                                                                        currencyCode
                                                                    }
                                                                }
                                                            }
                                                            taxLines {
                                                                priceSet {
                                                                    presentmentMoney {
                                                                        amount
                                                                        currencyCode
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                refunds {
                                                    id
                                                    totalRefundedSet {
                                                        presentmentMoney {
                                                            amount
                                                            currencyCode
                                                        }
                                                    }
                                                    return {
                                                        id
                                                        name
                                                    }
                                                }
                                                totalAmountProcessedSet {
                                                    presentmentMoney {
                                                        amount
                                                        currencyCode
                                                    }
                                                }
                                                totalPriceSet {
                                                    presentmentMoney {
                                                        amount
                                                        currencyCode
                                                    }
                                                }
                                                transactions {
                                                    id
                                                    parentTransaction {
                                                        id
                                                    }
                                                    kind
                                                    status
                                                    processedAt
                                                    amountSet {
                                                        presentmentMoney {
                                                            amount
                                                            currencyCode
                                                        }
                                                        shopMoney {
                                                            amount
                                                            currencyCode
                                                        }
                                                    }
                                                    gateway
                                                    paymentDetails {
                                                        ... on CardPaymentDetails {
                                                            company
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        pageInfo{
                                            endCursor
                                            hasNextPage
                                        }
                                    }
                                }
                            }
                        }

</@compress>