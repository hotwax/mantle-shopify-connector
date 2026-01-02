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
                        <#assign returnRefundFilter = "-return_status:'IN_PROGRESS' AND (return_status:'RETURNED' OR (return_status:'NO_RETURN' AND (financial_status:'PARTIALLY_REFUNDED' OR financial_status:'REFUNDED')) OR (financial_status:'PARTIALLY_REFUNDED' OR financial_status:'REFUNDED'))"/>
                       <#assign dateFilter = ""/>
                       <#if queryParams.fromDate?has_content && !queryParams.thruDate?has_content>
                       <#assign dateFilter = "updated_at:>'${queryParams.fromDate}'"/>
                       <#elseif queryParams.thruDate?has_content && !queryParams.fromDate?has_content>
                           <#assign dateFilter = "updated_at:<'${queryParams.thruDate}'"/>
                       <#elseif queryParams.fromDate?has_content && queryParams.thruDate?has_content>
                           <#assign dateFilter = "updated_at:>'${queryParams.fromDate}' AND updated_at:<'${queryParams.thruDate}'"/>
                       </#if>
                        <#if dateFilter?has_content>
                           <#assign filterQuery = "${dateFilter} AND ${returnRefundFilter}"/>
                       <#else>
                           <#assign filterQuery = returnRefundFilter/>
                       </#if>
                       query {
                           orders (first: 100<#if cursor?has_content>, after: "${cursor}"</#if><#if filterQuery?has_content>, query: "${filterQuery}"</#if>) {
                               edges {
                                   node {
                                       id
                                       name
                                       returnStatus
                                       refunds {
                                           id
                                       }
                                   }
                               }
                               pageInfo {
                                   endCursor
                                   hasNextPage
                               }
                           }
                       }
</@compress>