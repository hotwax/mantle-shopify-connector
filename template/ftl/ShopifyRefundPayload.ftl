<@compress single_line=true>

<#assign orderExternalId = "">
<#assign orderName = "">
<#if orderMap.id??>
    <#assign orderExternalId = Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(orderMap.id)>
    <#if orderMap.name??>
        <#assign orderName = orderMap.name>
    </#if>
</#if>

<#assign orderHeader = ec.entity.find("org.apache.ofbiz.order.order.OrderHeader")
                               .condition("externalId", orderExternalId)
                               .useCache(true)
                               .one()!>

<#if orderHeader?? && orderHeader.orderId?has_content>
    <#assign orderId = orderHeader.orderId>
<#else>
    <#assign orderId = "">
</#if>

<#assign refundExternalId = Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(refund.id)>

<#assign currency = "USD">
<#list refund.transactions?default([]) as txn>
    <#if txn.amountSet?? && txn.amountSet.shopMoney?? && txn.amountSet.shopMoney.currencyCode??>
        <#assign currency = txn.amountSet.shopMoney.currencyCode>
        <#break>
    </#if>
</#list>


<#assign returnType = "CUSTOMER_RETURN">
<#if refund.attributionType == "APPEASEMENT">
    <#assign returnType = "APPEASEMENT">
</#if>

<#assign shopifyShop = ec.entity.find("co.hotwax.shopify.ShopifyShop")
                               .condition("shopId", shopId)
                               .useCache(true)
                               .one()>

<#assign productStore = "">
<#if shopifyShop?? && shopifyShop.productStoreId?has_content>
    <#assign productStore = ec.entity.find("org.apache.ofbiz.product.store.ProductStore")
                                    .condition("productStoreId", shopifyShop.productStoreId)
                                    .useCache(true)
                                    .one()>
</#if>

<#assign companyId = "_NA_">
<#if productStore?? && productStore.payToPartyId?has_content>
    <#assign companyId = productStore.payToPartyId>
</#if>


<#assign returnChannel = "ECOM_RTN_CHANNEL">

<#if orderMap.refundAgreements??>
    <#list orderMap.refundAgreements as ra>
        <#if ra.refund?? && ra.refund.id == refund.id>
            <#if ra.app?? && ra.app.title??>
                <#if ra.app.title == "Loop Returns & Exchanges">
                    <#assign returnChannel = "LOOP_RETURN_CHANNEL">
                <#elseif ra.app.title == "Point of Sale">
                    <#assign returnChannel = "POS_RTN_CHANNEL">
                </#if>
            </#if>
            <#break>
        </#if>
    </#list>
</#if>


<#assign returnDate = "">
<#if refund.createdAt??>
    <#assign ts = ec.l10n.parseTimestamp(refund.createdAt,"yyyy-MM-dd'T'HH:mm:ssX")>
    <#assign returnDate = ec.l10n.format(ts,"yyyy-MM-dd HH:mm:ss")>
</#if>

<#assign shipFacilityId = "_NA_">

<#if refund.refundLineItems?has_content && refund.refundLineItems[0].location?? && refund.refundLineItems[0].location.id??>
    <#assign shopifyLocationId = Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(refund.refundLineItems[0].location.id)>
    <#assign facility = ec.entity.find("co.hotwax.shopify.ShopifyShopLocation")
                                .condition("shopifyLocationId", shopifyLocationId)
                                .condition("shopId", shopId)
                                .useCache(true)
                                .one()!>

    <#if facility?? && facility.facilityId??>
        <#assign shipFacilityId = facility.facilityId>
    </#if>
</#if>

<#assign finalReturnType = returnType>
<#if shipFacilityId == "_NA_">
    <#assign finalReturnType = "APPEASEMENT">
</#if>

<#assign totalItemReturnAmount = 0>
<#assign refundAmount = 0>
<#assign returnPaymentPrefList = []>


<#list refund.transactions?default([]) as txn>
    <#if txn.kind == "REFUND" && txn.amountSet?? && txn.amountSet.presentmentMoney??>
        <#assign refundAmount += txn.amountSet.presentmentMoney.amount?number>
    </#if>
    <#assign mapTxnResp = ec.service.sync().name("co.hotwax.sob.order.ShopifyOrderMappingServices.map#OrderTransaction").parameter("shopifyOrderId", orderMap.id).parameter("shopId", shopId).parameter("shopifyTransaction", txn).call().orderPaymentPreference!/>
    <#if mapTxnResp?? && mapTxnResp.manualRefNum?has_content>
        <#assign returnPaymentPrefList += [mapTxnResp]>
        <#else>
        <#assign resolvedTxnId = Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(txn.id)>
        <#assign presentmentAmt = 0>
        <#assign maxAmt = 0>
        <#if txn.amountSet??>
            <#if txn.amountSet.presentmentMoney??>
                <#assign presentmentAmt = txn.amountSet.presentmentMoney.amount>
            </#if>
            <#if txn.amountSet.shopMoney??>
                <#assign maxAmt = txn.amountSet.shopMoney.amount>
            </#if>
        </#if>
        <#if orderId?? && orderId?has_content>
            <#assign existingOpp = ec.entity.find("org.apache.ofbiz.order.order.OrderPaymentPreference").condition("orderId", orderId).condition("manualRefNum", resolvedTxnId).one()!>
        </#if>
        <#if existingOpp?? && existingOpp?has_content>
            <#assign pref = {
                "paymentMethodTypeId": existingOpp.paymentMethodTypeId,
                "statusId": "PAYMENT_REFUNDED",
                "orderPaymentPreferenceId": existingOpp.orderPaymentPreferenceId,
                "manualRefNum": resolvedTxnId,
                "presentmentCurrencyUom": (currency!"USD"),
                "presentmentAmount": presentmentAmt,
                "maxAmount": maxAmt,
                "orderExternalId": orderExternalId
            }>
            <#assign returnPaymentPrefList += [pref]>
        <#else>
            <#assign fallbackPref = {
                "paymentMethodTypeId": "EXT_SHOP_OTHR_GTWAY",
                "statusId": "PAYMENT_REFUNDED",
                "manualRefNum": resolvedTxnId,
                "parentRefNum": Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(txn.parentTransaction.id),
                "presentmentCurrencyUom": (currency!"USD"),
                "presentmentAmount": presentmentAmt,
                "maxAmount": maxAmt,
                "orderExternalId": orderExternalId
            }>
            <#assign returnPaymentPrefList += [fallbackPref]>
        </#if>
    </#if>
</#list>

<#assign finalAdjustments = []>

<#if refund.refundShippingLines?? && refund.refundLineItems?has_content>
    <#list refund.refundShippingLines as rsl>

        <#assign shippingRefund = (rsl.subtotalAmountSet.presentmentMoney.amount?number)!0>
        <#if shippingRefund gt 0>
            <#assign adj = {
                "amount": shippingRefund,
                "type": "RET_SHIPPING_ADJ",
                "comments": "Shipping refund",
                "description": "Shipping refund"
            }>

            <#if orderId?has_content>
                <#assign adj = adj + {"orderId": orderId}>
            </#if>

            <#assign finalAdjustments += [adj]>
            <#assign totalItemReturnAmount += shippingRefund>
        </#if>

        <#assign shippingTaxRefund = (rsl.taxAmountSet.presentmentMoney.amount?number)!0>
        <#if shippingTaxRefund gt 0>
            <#assign adj = {
                "amount": shippingTaxRefund,
                "type": "RET_SALES_TAX_ADJ",
                "comments": "Shipping Tax Refund",
                "description": "Shipping Tax Refund"
            }>

            <#if orderId?has_content>
                <#assign adj = adj + {"orderId": orderId}>
            </#if>

            <#assign finalAdjustments += [adj]>
            <#assign totalItemReturnAmount += shippingTaxRefund>
        </#if>

    </#list>
</#if>

<#if refund.orderAdjustments?? && refund.orderAdjustments?has_content>
    <#list refund.orderAdjustments as orderAdj>
        <#assign adjAmount = (orderAdj.amountSet.presentmentMoney.amount?number) * -1>
            <#assign adj = {
                "amount": adjAmount,
                "type": "APPEASEMENT",
                "comments": "Shopify Order Adjustment",
                "description": "Refund Adjustment for orderId ${orderExternalId}"
            }>

            <#if orderId?has_content>
                <#assign adj = adj + {"orderId": orderId}>
            </#if>

            <#assign finalAdjustments += [adj]>
            <#assign totalItemReturnAmount += adjAmount>
    </#list>
</#if>

{
    "payLoad": {
        "externalId": "${refundExternalId}",
        "type": "${finalReturnType}",
        "status": "RETURN_COMPLETED",
        "companyId": "${companyId}",
        "returnDate": "${returnDate}",
        "returnChannelEnumId": "${returnChannel}",

        <#if orderMap.customer?? && orderMap.customer.id??>
            "customerIdentificationType": "SHOPIFY_CUST_ID",
            "customerIdentificationValue": "${Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(orderMap.customer.id)}",
            <#else>
            "customerId": "_NA_",
        </#if>

       <#assign availableReturnItems = []>
        <#if refund.return?? && refund.return.returnLineItems??>
            <#list refund.return.returnLineItems as rli>
                <#assign availableReturnItems += [{
                    "quantity": rli.quantity!0,
                    "reason": rli.returnReason!"UNKNOWN"
                }]>
            </#list>
        </#if>

        "currencyCode": "${currency}",
        "items": [
            <#assign idx = 0>
            <#list refund.refundLineItems?default([]) as rli>
                <#if idx gt 0>,</#if>
                <#assign idx += 1>
                <#assign itemAdjustments = []>
                <#assign orderedQty = rli.lineItem.quantity!1>
                <#assign totalDiscount = 0>

                <#if rli.lineItem.discountAllocations??>
                    <#list rli.lineItem.discountAllocations as discount>
                        <#assign totalDiscount += (discount.allocatedAmountSet.presentmentMoney.amount?number)!0>
                        <#assign discountAmt = (discount.allocatedAmountSet.presentmentMoney.amount?number)!0>
                        <#assign adjAmt = -(discountAmt / orderedQty)>
                        <#if adjAmt lt 0>
                            <#assign itemAdjustments += [{
                                "itemExternalId": Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(rli.id),
                                "amount": adjAmt,
                                "type": "RET_EXT_PRM_ADJ",
                                "comments": "External Discount",
                                "description": "Return External Promotion Adjustment"
                            }]>
                        </#if>
                    </#list>
                </#if>

                <#if rli.lineItem.taxLines??>
                    <#list rli.lineItem.taxLines as taxLine>
                        <#assign tAmt = (taxLine.priceSet.presentmentMoney.amount?number)!0>
                        <#if tAmt gt 0>
                            <#assign itemAdjustments += [{
                                "itemExternalId": Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(rli.id),
                                "amount": tAmt,
                                "type": "RET_SALES_TAX_ADJ",
                                "comments": taxLine.title!"Tax",
                                "description": "Return Sales Tax"
                            }]>
                        </#if>
                    </#list>
                </#if>
               <#assign returnReason = "UNKNOWN">
                <#assign matchedIndex = -1>

                <#list availableReturnItems as retItem>
                    <#if retItem.quantity == rli.quantity>
                        <#assign returnReason = retItem.reason>
                        <#assign matchedIndex = retItem?index>
                        <#break>
                    </#if>
                </#list>

                <#if returnReason == "UNKNOWN" && availableReturnItems?size == 1>
                    <#assign returnReason = availableReturnItems[0].reason>
                    <#assign matchedIndex = 0>
                </#if>

                <#if matchedIndex gte 0>
                    <#assign newAvailableReturnItems = []>
                    <#list availableReturnItems as it>
                        <#if it?index != matchedIndex>
                            <#assign newAvailableReturnItems += [it]>
                        </#if>
                    </#list>
                    <#assign availableReturnItems = newAvailableReturnItems>
                </#if>

                <#assign productId = "">

                <#if rli.lineItem?? && rli.lineItem.variant?? && rli.lineItem.variant.id??>
                    <#assign shopifyVariantId = Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(rli.lineItem.variant.id)>

                    <#assign shopifyShopProduct = ec.entity.find("co.hotwax.shopify.ShopifyShopProduct")
                                                           .condition("shopId", shopId)
                                                           .condition("shopifyProductId", shopifyVariantId)
                                                           .useCache(true)
                                                           .one()!>

                    <#if shopifyShopProduct?? && shopifyShopProduct.productId??>
                        <#assign productId = shopifyShopProduct.productId>
                    </#if>
                </#if>

                <#if !productId?has_content && rli.lineItem?? && rli.lineItem.sku?has_content>

                    <#assign skuProduct = ec.entity.find("org.apache.ofbiz.product.product.GoodIdentification")
                                                   .condition("goodIdentificationTypeId", "SKU")
                                                   .condition("idValue", rli.lineItem.sku)
                                                   .useCache(true)
                                                   .one()!>

                    <#if skuProduct?? && skuProduct.productId??>
                        <#assign productId = skuProduct.productId>
                    </#if>
                </#if>


                <#assign restockType = (rli.restockType!"no_restock")?lower_case>
                <#assign itemAmount = 0>
                <#assign taxAmount = 0>
                <#assign totalItemAmount = 0>

                <#if rli.priceSet?? && rli.priceSet.shopMoney??>
                    <#assign itemAmount = rli.priceSet.shopMoney.amount?number>
                </#if>
                <#if rli.totalTaxSet?? && rli.totalTaxSet.shopMoney??>
                    <#assign taxAmount = rli.totalTaxSet.shopMoney.amount?number>
                </#if>
                <#if rli.subtotalSet?? && rli.subtotalSet.presentmentMoney??>
                    <#assign totalItemAmount = rli.subtotalSet.presentmentMoney.amount?number>
                </#if>

                {
                "itemExternalId": "${Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(rli.id)}",
                "orderItemExternalId": "${Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(rli.lineItem.id)}",
                "id": "${productId}",
                "status": "RETURN_COMPLETED",
                "quantity": ${rli.quantity!0},
                "reason": "${returnReason}",
                "returnType": "RTN_REFUND",
                <#if orderId?has_content>
                    "orderExternalId": "${orderExternalId}",
                    "orderName": "${orderName}",
                </#if>
                "includeAdjustments": "N",
                <#if restockType == "no_restock">
                    "itemTypeId": "RET_LOST_ITEM",
                    "restockType": "INV_NOT_RETURNED",
                    "receivedQty": 0
                <#else>
                    "itemTypeId": "RET_FPROD_ITEM",
                    "restockType": "INV_RETURNED",
                    "receivedQty": ${rli.quantity}
                </#if>

                    ,"price": ${itemAmount}
                    <#if itemAdjustments?has_content>
                    ,"itemAdjustments": [
                        <#list itemAdjustments as adj>
                            <#if adj?index gt 0>,</#if>
                            {
                                "itemExternalId": "${adj.itemExternalId}",
                                "amount": ${adj.amount},
                                "type": "${adj.type}",
                                "comments": "${adj.comments}",
                                "description": "${adj.description}"
                            }
                        </#list>
                    ]
                    </#if>
                }
                <#assign totalItemReturnAmount += (totalItemAmount + taxAmount)>
            </#list>
        ],
        <#assign hasExchange = false>
        <#if refund.return?? && refund.return.exchangeLineItems?has_content>
            <#assign hasExchange = true>
        </#if>
        <#assign exchangeAmount = 0>
        <#if hasExchange>
            <#assign exchangeAmount = totalItemReturnAmount - refundAmount>
            <#if exchangeAmount lt 0>
                <#assign exchangeAmount = 0>
            </#if>
        </#if>

        "shipTo": {
            "facilityId": "${shipFacilityId}"
        },

        "refundAmount": ${refundAmount},
        "totalReturnAmount": ${totalItemReturnAmount},
        "exchangeCredit": ${exchangeAmount},

        "returnPaymentPref": [
            <#assign rpIdx = 0>
            <#list returnPaymentPrefList as rpp>
            <#if rpIdx gt 0>,</#if>
            <#assign rpIdx += 1>
                {
                "paymentMethodTypeId": "${rpp.paymentMethodTypeId!'EXT_SHOP_OTHR_GTWAY'}",
                "statusId": "${rpp.statusId!'PAYMENT_REFUNDED'}",
                "manualRefNum": "${rpp.manualRefNum!''}"
                <#if rpp.parentRefNum??>
                ,"parentRefNum": "${rpp.parentRefNum}"
                </#if>
                <#if rpp.presentmentCurrencyUom??>
                ,"presentmentCurrencyUom": "${rpp.presentmentCurrencyUom}"
                </#if>
                <#if rpp.presentmentAmount??>
                ,"presentmentAmount": ${rpp.presentmentAmount}
                </#if>
                <#if rpp.maxAmount??>
                ,"maxAmount": ${rpp.maxAmount}
                </#if>
                ,"orderExternalId": "${orderExternalId}"
                }
            </#list>
        ],

        <#if finalAdjustments?has_content>
        ,"returnAdjustment": [
            <#list finalAdjustments as adj>
                <#if adj?index gt 0>,</#if>
                {
                    <#if adj.orderId?has_content>
                    "orderId": "${adj.orderId}",
                    </#if>
                    "amount": ${adj.amount},
                    "type": "${adj.type}",
                    "comments": "${adj.comments}",
                    "description": "${adj.description}"
                }
            </#list>
        ],
        </#if>

        "returnIdentifications": [
        {
            "returnIdentificationTypeId": "SHOPIFY_RTN_ID",
            "idValue": "${refundExternalId}"
        }
        <#if !orderId?has_content>,
        {
            "returnIdentificationTypeId": "SHPY_ORPN_RTN_ORD_ID",
            "idValue": "${orderExternalId}"
        }
        </#if>
        ]
    }
}

</@compress>