
import java.math.RoundingMode
import co.hotwax.shopify.util.ShopifyHelper
import org.moqui.util.CollectionUtilities

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


BigDecimal totalReturnAmount = 0.0

def itemsList = refund.refundLineItems.collect { rli ->
    def lineItem = rli.lineItem
    def qtyRatio = rli.quantity / lineItem.quantity
    def isRestocked = rli.restockType && rli.restockType != 'no_restock'
    def prorate = { val -> (val as BigDecimal * qtyRatio).setScale(2, RoundingMode.HALF_UP) }

    def productId = ec.entity.find("co.hotwax.shopify.ShopifyShopProduct").condition("shopId", shopId).condition("shopifyProductId", ShopifyHelper.resolveShopifyGid(lineItem.variant?.id)).selectField("productId").useCache(true).one()?.productId

    if(!productId) {
        prodIdentifications = ec.entity.find("org.apache.ofbiz.product.product.GoodIdentification").condition(["productId": productId, "goodIdentificationTypeId": "SKU"]).selectField("productId,fromDate,thruDate").useCache(true).list()
        productId = CollectionUtilities.filterMapListByDate(prodIdentifications, null, null, ec.user.nowTimestamp).get(0)?.productId
    }
    
    def isCustomGiftCard = lineItem.isGiftCard && !(lineItem.variant?.id)

    // Calculate item total for header
    def itemAmt = (rli.subtotalSet?.shopMoney?.amount as BigDecimal) ?: 0.0
    def itemTax = (rli.totalTaxSet?.shopMoney?.amount as BigDecimal) ?: 0.0
    totalReturnAmount += (itemAmt + itemTax)

    [
        id: productId, // TODO: Handle custom gift card productId 
        itemExternalId: ShopifyHelper.resolveShopifyGid(rli.id), // Refund Line Item ID
        orderItemExternalId: ShopifyHelper.resolveShopifyGid(lineItem.id), // Order Line Item ID
        quantity: rli.quantity,
        status: "RETURN_COMPLETED",
        price: rli.priceSet.shopMoney.amount,
        returnType: "RTN_REFUND",
        restockType: isRestocked ? 'INV_RETURNED' : 'INV_NOT_RETURNED',
        itemTypeId: isRestocked ? 'RET_FPROD_ITEM' : 'RET_LOST_ITEM',
        receivedQty: isRestocked ? rli.quantity : 0,
        reason: returnReasonMap?.get(ShopifyHelper.resolveShopifyGid(lineItem.id)) ?: 'UNKNOWN',
        includeAdjustments: 'N',
        itemAdjustments: (
            lineItem.discountAllocations.collect { [
                type: "RET_EXT_PRM_ADJ", 
                description: "External Discount", 
                amount: prorate(it.allocatedAmountSet.shopMoney.amount), 
                comments: "Prorated discount",
            ] } +
            lineItem.taxLines.collect { [
                type: "RET_SALES_TAX_ADJ", 
                description: it.title, 
                amount: prorate(it.priceSet.shopMoney.amount), 
                sourcePercentage: it.rate * 100, 
                comments: "${it.title} (${it.rate * 100}%)"
            ] }
        )
    ].with { m -> if(!isOrphan) m.orderExternalId = shopifyOrderId; m }
}


def adjustmentsList = (
    // Shipping 
    refund.refundShippingLines.collectMany { rsl ->
        def shipAmt = (rsl.subtotalAmountSet?.shopMoney?.amount as BigDecimal) ?: 0.0
        def taxAmt = (rsl.taxAmountSet?.shopMoney?.amount as BigDecimal) ?: 0.0
        
        totalReturnAmount += (shipAmt + taxAmt)

        [
            [type: "RET_SHIPPING_ADJ", amount: shipAmt, description: "Shipping Refund"],
            [type: "RET_SALES_TAX_ADJ", amount: taxAmt, description: "Shipping Tax Refund"]
        ]
    } +
    // Order Adjustments
    refund.orderAdjustments.collect { oa ->
        def amount = (oa.amountSet?.shopMoney?.amount as BigDecimal ?: 0.0).multiply(-1)
        
        totalReturnAmount += amount

        [type: "APPEASEMENT", amount: amount, description: "Refund Adjustment for orderId ${shopifyOrderId}", comments: "Shopify Order Adjustment"]
    }
).findAll { it.amount }

result = [
    payLoad: [
        externalId: refundId,
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
        totalReturnAmount: totalReturnAmount,
        items: itemsList,
        returnAdjustment: adjustmentsList,
        returnPaymentPref: refund.transactions
            .findAll { it.kind == "REFUND" && it.status == "SUCCESS" }
            .collect {
                txMappingResult = ec.service.sync().name("co.hotwax.sob.order.ShopifyOrderMappingServices.map#OrderTransaction").parameters([shopifyOrderId:shopifyOrderId, shopId:shopId, shopifyTransaction: it]).call()
                if (ec.message.hasError()) {
                    ec.logger.warn("Failed to map transaction ${it.id} for order ${shopifyOrderId}")
                    ec.message.clearErrors()
                }
                txMappingResult?.orderPaymentPreference
            }.findAll { it },
        returnIdentifications: [returnIdentificationTypeId: "SHOPIFY_RTN_ID", idValue: refundId] + (isOrphan ? [returnIdentificationTypeId: "SHPY_ORPN_RTN_ORD_ID", idValue: ShopifyHelper.resolveShopifyGid(order.id)] : [])
    ]
]