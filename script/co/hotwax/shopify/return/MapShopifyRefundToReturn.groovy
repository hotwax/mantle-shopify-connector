
import java.math.RoundingMode
import co.hotwax.shopify.util.ShopifyHelper

shopifyShop = ec.entity.find("co.hotwax.shopify.ShopifyShop").condition("shopId", shopId).useCache(true).one()
productStore = shopifyShop?.'org.apache.ofbiz.product.store.ProductStore'

returnChannelEnumMapping = ['Loop Return & Echanges': "LOOP_RETURN_CHANNEL", "Point of Sale": "POS_RTN_CHANNEL"].withDefault {'ECOM_RTN_CHANNEL'}

refundChannel = order.refundAgreements.findAll {it.__typename == 'RefundAgreement'}.collectEntries {[(ShopifyHelper.resolveShopifyGid(it.refund.id)): returnChannelEnumMapping.get(it.app?.title)]}


// Inside iteration
def locationId = refund.refundLineItems?.find { it.location?.id }?.location?.id
shipToFacilityId = ec.entity.find("co.hotwax.shopify.ShopifyShopLocation").condition("shopId", shopId).condition("shopifyLocationId", ShopifyHelper.resolveShopifyGid(locationId)).useCache(true).selectField("facilityId").one()?.facilityId ?: '_NA_'

/*
// Option 1: Enrich refundLineItems directly
refund.refundLineItems.each { rli ->
    rli.returnReason = refund.return?.returnLineItems?.find { 
        ShopifyHelper.resolveShopifyGid(it.fulfillmentLineItem?.lineItem?.id) == ShopifyHelper.resolveShopifyGid(rli.lineItem?.id) 
    }?.returnReason
}
*/

// Option 2: Create a Map and use it during iteration
def returnReasonMap = refund.return?.returnLineItems?.collectEntries {
    [(ShopifyHelper.resolveShopifyGid(it.fulfillmentLineItem?.lineItem?.id)): it.returnReason]
}

refundId = ShopifyHelper.resolveShopifyGid(refund.id)
shopifyOrderId = ShopifyHelper.resolveShopifyGid(order.id) // TODO: Remove as already they will be in the context

result = [
    payLoad: [
        externalId: refundId,
        orderExternalId: shopifyOrderId,
        type: shipToFacilityId == "_NA_" ? "APPEASEMENT" : (refund.attributionType ?: "CUSTOMER_RETURN"),
        status: "RETURN_COMPLETED",
        companyId: productStore.payToPartyId ?: '_NA_',
        returnDate: ec.l10n.format(ec.l10n.parseTimestamp(refund.createdAt, null), "yyyy-MM-dd HH:mm:ss"),
        returnChannelEnumId: refundChannel.get(refundId),
        customerIdentificationType: "SHOPIFY_CUST_ID",
        customerIdentificationValue: ShopifyHelper.resolveShopifyGid(order?.customer?.id),
        shipTo: [facilityId: shipToFacilityId],
        currencyCode: refund.totalRefundedSet.shopMoney.currencyCode,
        grandTotal: refund.totalRefundedSet.shopMoney.amount,
        items: refund.refundLineItems.collect { rli ->
            def lineItem = rli.lineItem
            def qtyRatio = rli.quantity / lineItem.quantity
            def isRestocked = rli.restockType && rli.restockType != 'no_restock'
            def prorate = { val -> (val as BigDecimal * qtyRatio).setScale(2, RoundingMode.HALF_UP) }

            [
                id: ShopifyHelper.resolveShopifyGid(lineItem.variant?.id), // TODO: Requires internal productId resolution
                itemExternalId: ShopifyHelper.resolveShopifyGid(rli.id), // Refund Line Item ID
                orderItemExternalId: ShopifyHelper.resolveShopifyGid(lineItem.id), // Order Line Item ID
                sku: lineItem.sku,
                quantity: rli.quantity,
                status: "RETURN_COMPLETED",
                price: rli.priceSet.shopMoney.amount,
                returnType: "RTN_REFUND",
                restockType: isRestocked ? 'INV_RETURNED' : 'INV_NOT_RETURNED',
                itemTypeId: isRestocked ? 'RET_FPROD_ITEM' : 'RET_LOST_ITEM',
                receivedQty: isRestocked ? rli.quantity : 0,
                reason: returnReasonMap?.get(ShopifyHelper.resolveShopifyGid(lineItem.id)) ?: 'UNKNOWN',
                itemAdjustments: (
                    lineItem.discountAllocations.collect { [
                        type: "RET_EXT_PRM_ADJ", 
                        description: "External Discount", 
                        amount: prorate(it.allocatedAmountSet.shopMoney.amount), 
                        comments: "Prorated discount"
                    ] } +
                    lineItem.taxLines.collect { [
                        type: "RET_SALES_TAX_ADJ", 
                        description: it.title, 
                        amount: prorate(it.priceSet.shopMoney.amount), 
                        sourcePercentage: it.rate * 100, 
                        comments: "${it.title} (${it.rate * 100}%)"
                    ] }
                )
            ]
        },
        returnAdjustment: (
            refund.refundShippingLines.collectMany {[
                [type: "RET_SHIPPING_ADJ", amount: it.subtotalAmountSet?.shopMoney?.amount, description: "Shipping Refund"],
                [type: "RET_SALES_TAX_ADJ", amount: it.taxAmountSet?.shopMoney?.amount, description: "Shipping Tax Refund"]
            ]} +
            refund.orderAdjustments.collect { 
                [type: "APPEASEMENT", amount: it.amountSet?.shopMoney?.amount, description: "Refund Adjustment for orderId ${shopifyOrderId}", comments: "Shopify Order Adjustment"] 
            }
        ).findAll { it.amount },
        returnPaymentPref: refund.transactions
            .findAll { it.kind == "REFUND" && it.status == "SUCCESS" }
            .collect {[
                paymentMethodTypeId: "EXT_SHOP_OTHR_GTWAY",
                statusId: "PAYMENT_REFUNDED",
                manualRefNum: ShopifyHelper.resolveShopifyGid(it.id),
                parentRefNum: ShopifyHelper.resolveShopifyGid(it.parentTransaction?.id),
                presentmentCurrency: it.amountSet.presentmentMoney.currencyCode,
                maxAmount: it.amountSet.shopMoney.amount,
                presentmentAmount: it.amountSet.presentmentMoney.amount
            ]},
        returnIdentifications: [
            [returnIdentificationTypeId: "SHOPIFY_RTN_ID", idValue: refundId],
            [returnIdentificationTypeId: "SHPY_ORPN_RTN_ORD_ID", idValue: ShopifyHelper.resolveShopifyGid(order.id)]
        ]
    ]
]