<@compress single_line=true>

<#assign orderExternalId = "">
<#if orderMap.id??>
    <#assign orderExternalId = Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(orderMap.id)>
    <#assign orderName= orderMap.name>
</#if>

<#assign orderHeader = ec.entity.find("org.apache.ofbiz.order.order.OrderHeader")
                                .condition("externalId", orderExternalId)
                                .useCache(true)
                                .one()!>

<#if orderHeader?? && orderHeader.orderId?has_content>
    <#assign orderId = orderHeader.orderId>
<#else>
    <#assign orderId = null>
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
<#if refund.refundAgreement?? && refund.refundAgreement.app?? && refund.refundAgreement.app.title??>
    <#if refund.refundAgreement.app.title == "Loop">
        <#assign returnChannel = "LOOP_RETURN_CHANNEL">
    <#elseif refund.refundAgreement.app.title == "Point of Sale">
        <#assign returnChannel = "POS_RTN_CHANNEL">
    </#if>
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
<#assign paymentAmount = 0>
<#assign returnPaymentPrefList = []>


<#list refund.transactions?default([]) as txn>
    <#if txn.kind == "REFUND" && txn.amountSet?? && txn.amountSet.presentmentMoney??>
        <#assign refundAmount += txn.amountSet.presentmentMoney.amount?number>
    </#if>
    <#if txn.kind == "SALE" && txn.amountSet?? && txn.amountSet.presentmentMoney??>
        <#assign paymentAmount += txn.amountSet.presentmentMoney.amount?number>
    </#if>
    <#assign mapTxnResp = ec.service.sync().name("co.hotwax.sob.order.ShopifyOrderMappingServices.map#OrderTransaction").parameter("shopifyOrderId", orderMap.id).parameter("shopId", shopId).parameter("shopifyTransaction", txn).call().orderPaymentPreference!/>
    <#if mapTxnResp??>
        <#assign returnPaymentPrefList += [mapTxnResp]>
        <#else>
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
            <#assign fallbackPref = {
                "paymentMethodTypeId": "EXT_SHOP_OTHR_GTWAY",
                "statusId": "PAYMENT_REFUNDED",
                "manualRefNum": Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(txn.id),
                "parentRefNum": Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(txn.parentTransaction.id),
                "presentmentCurrencyUom": (currency!"USD"),
                "presentmentAmount": presentmentAmt,
                "maxAmount": maxAmt,
                "orderExternalId": orderExternalId
            }>
            <#assign returnPaymentPrefList += [fallbackPref]>
    </#if>
</#list>

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

        "currencyCode": "${currency}",
        "items": [
            <#assign idx = 0>
            <#list refund.refundLineItems?default([]) as rli>
                <#if idx gt 0>,</#if>
                <#assign idx += 1>

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

                <#if rli.subtotalSet?? && rli.subtotalSet.presentmentMoney??>
                    <#assign itemAmount = rli.subtotalSet.presentmentMoney.amount?number>
                </#if>
                <#if rli.totalTaxSet?? && rli.totalTaxSet.presentmentMoney??>
                    <#assign taxAmount = rli.totalTaxSet.presentmentMoney.amount?number>
                </#if>

                {
                "itemExternalId": "${Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(rli.id)}",
                "orderItemExternalId": "${Static["co.hotwax.shopify.util.ShopifyHelper"].resolveShopifyGid(rli.lineItem.id)}",
                "id": "${productId}",
                "status": "RETURN_COMPLETED",
                "quantity": ${rli.quantity!0},
                "reason": "UNKNOWN",
                "returnType": "RTN_REFUND",
                <#if orderId??>
                    "orderExternalId": "${orderExternalId}",
                    "orderName": "${orderName}",
                </#if>

                <#if restockType == "no_restock">
                    "itemTypeId": "RET_LOST_ITEM",
                    "restockType": "INV_NOT_RETURNED"
                <#else>
                    "itemTypeId": "RET_FPROD_ITEM",
                    "restockType": "INV_RETURNED"
                </#if>

                <#if !orderId??>
                    ,"price": ${itemAmount},
                    "itemAdjustments": []
                </#if>
                }
                <#assign totalItemReturnAmount += (itemAmount + taxAmount)>
            </#list>
        ],

        "shipTo": {
            "facilityId": "${shipFacilityId}"
        },

        "refundAmount": ${refundAmount},
        "paymentAmount": ${paymentAmount},
        "totalReturnAmount": ${totalItemReturnAmount},

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



        "returnIdentifications": [
        {
            "returnIdentificationTypeId": "SHOPIFY_RTN_ID",
            "idValue": "${refundExternalId}"
        }
        <#if !orderExternalId?has_content>,
        {
            "returnIdentificationTypeId": "SHPY_ORPN_RTN_ORD_ID",
            "idValue": "${orderExternalId}"
        }
        </#if>
        ]
    }
}

</@compress>