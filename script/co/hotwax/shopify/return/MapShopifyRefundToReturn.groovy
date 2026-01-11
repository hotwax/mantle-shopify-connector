
import groovy.json.JsonSlurper
import groovy.json.JsonOutput
import java.math.RoundingMode
import co.hotwax.shopify.util.ShopifyHelper

// Context variables 'order' and 'refund' are automatically available from the service input

result = [
    payLoad: [
        externalId: ShopifyHelper.resolveShopifyGid(refund.id),
        orderExternalId: ShopifyHelper.resolveShopifyGid(order.id),
        type: "CUSTOMER_RETURN",
        status: "RETURN_COMPLETED",
        createdDate: refund.createdAt,
        currencyCode: refund.totalRefundedSet.shopMoney.currencyCode,
        grandTotal: refund.totalRefundedSet.shopMoney.amount,
        items: refund.refundLineItems.collect { rli ->
            def lineItem = rli.lineItem
            def qtyRatio = rli.quantity / lineItem.quantity
            
            def prorate = { val -> (val as BigDecimal * qtyRatio).setScale(2, RoundingMode.HALF_UP) }

            [
                id: ShopifyHelper.resolveShopifyGid(lineItem.variant?.id),
                itemExternalId: ShopifyHelper.resolveShopifyGid(lineItem.id),
                sku: lineItem.sku,
                quantity: rli.quantity,
                status: "RETURN_COMPLETED",
                price: rli.priceSet.shopMoney.amount,
                returnType: "RTN_REFUND",
                restockType: rli.restockType,
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
            refund.refundShippingLines.collect { 
                [type: "RET_SHIPPING_ADJ", amount: it.subtotalAmountSet?.shopMoney?.amount, description: "Shipping Refund"] 
            } +
            refund.refundShippingLines.collect { 
                [type: "RET_SALES_TAX_ADJ", amount: it.taxAmountSet?.shopMoney?.amount, description: "Shipping Tax Refund"] 
            } +
            refund.orderAdjustments.collect { 
                [type: "RET_ORDER_ADJ", amount: it.amountSet?.shopMoney?.amount, description: "Order Adjustment"] 
            }
        ).findAll { it.amount > 0 },
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
            [returnIdentificationTypeId: "SHOPIFY_RTN_ID", idValue: ShopifyHelper.resolveShopifyGid(refund.id)],
            [returnIdentificationTypeId: "SHPY_ORPN_RTN_ORD_ID", idValue: ShopifyHelper.resolveShopifyGid(order.id)]
        ]
    ]
]