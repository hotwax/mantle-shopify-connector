package co.hotwax.shopify

import org.moqui.context.ExecutionContext
import org.moqui.entity.EntityValue


class ShopifyMappingWorker {
    static String getShopifyTypeMappedValue(ExecutionContext ec, String shopId, String mappedType, String mappedKey, String defaultValue = null) {
        EntityValue mapping
        try {
            mapping = ec.entity.find("ShopifyShopTypeMapping")
                    .condition("shopId", shopId)
                    .condition("mappedTypeId", mappedType)
                    .condition("mappedKey", mappedKey ? mappedKey.toUpperCase() : null)
                    .one()
        } catch (Exception e) {
            ec.logger.error("Error fetching ShopifyShopTypeMapping for shopId=${shopId}, mappedType=${mappedType}, mappedKey=${mappedKey}: ${e.message}", e)
            return defaultValue
        }
        return mapping?.mappedValue ?: defaultValue
    }
    static String getFacilityId(ExecutionContext ec, String shopifyConfigId, String shopifyLocationId) {
        EntityValue shopifyLocation
        try {
            shopifyLocation = ec.entity.find("ShopifyConfigAndShopLocation")
                    .condition("shopifyConfigId", shopifyConfigId)
                    .condition("shopifyLocationId", shopifyLocationId)
                    .one()
        } catch (Exception e) {
            ec.logger.error("Error fetching ShopifyConfigAndShopLocation for shopifyConfigId=${shopifyConfigId}, shopifyLocationId=${shopifyLocationId}: ${e.message}", e)
            return null
        }

        return shopifyLocation?.facilityId
    }

    static String getProductId(ExecutionContext ec, String shopifyConfigId, String shopifyProductId) {
        EntityValue shopifyProduct

        try {
            shopifyProduct = ec.entity.find("co.hotwax.shopify.ShopifyShopProductAndConfig")
                    .condition("shopifyConfigId", shopifyConfigId)
                    .condition("shopifyProductId", shopifyProductId)
                    .one()
        } catch (Exception e) {
            ec.logger.error(
                    "Error fetching ShopifyShopProductAndConfig for shopifyConfigId=${shopifyConfigId}, " + "shopifyProductId=${shopifyProductId}: ${e.message}", e)
            return null
        }

        return shopifyProduct?.productId
    }
    static String getFacilityContactId(ExecutionContext ec, String facilityId, String contactMechTypeId, String contactMechPurposeTypeId)
    {
        EntityValue facilityContactDetails

        try {
            facilityContactDetails = ec.entity.find("FacilityContactDetailByPurpose")
                    .condition("facilityId", facilityId)
                    .condition("contactMechTypeId", contactMechTypeId)
                    .condition("contactMechPurposeTypeId", contactMechPurposeTypeId)
                    .orderBy("fromDate DESC")
                    .one()
        }
        catch (Exception e){
            ec.logger.error("Error fetching FacilityContactDetailByPurpose for facilityId=${facilityId}, " +
                    "contactMechTypeId=${contactMechTypeId}, contactMechPurposeTypeId=${contactMechPurposeTypeId}: ${e.message}", e)
            return null
        }
        return facilityContactDetails?.contactMechId
    }

    static List<Map<String, Object>> explodeOrderItems(List<Map<String, Object>> items, ExecutionContext ec) {

        List<Map<String, Object>> orderItemList = []

        try {
            if (items) {
                items.each { item ->
                    orderItemList.addAll(explodeOrderItem(item, ec))
                }
            }
        } catch (Throwable t) {
        ec.logger.error("Error exploding order items: " + t.getMessage(), t)}
        return orderItemList
    }

    static List<Map<String, Object>> explodeOrderItem(Map<String, Object> itemMap, ExecutionContext ec) {

        def result = []

        int origQty = (itemMap.quantity ?: 0) as int
        if (origQty <= 0) return result

        // ---- STATUS COUNTS ----
        int fulfilledQty = (itemMap.fulfilledQty ?: 0) as int
        int canceledQty  = (itemMap.canceledQty ?: 0) as int
        int unfulfilledQty = origQty - fulfilledQty - canceledQty

        int remainingCompleted = fulfilledQty
        int remainingCancelled = canceledQty

        def adjustments = (itemMap.adjustments instanceof List) ? itemMap.adjustments : []

        for (int i = 1; i <= origQty; i++) {

            def newItem = new HashMap(itemMap)
            def newAdjList = []

            // ---- SPLIT ADJUSTMENTS ----
            adjustments.each { adj ->

                BigDecimal total = (adj.amount ?: 0) as BigDecimal

                BigDecimal perUnit =
                        total.divide(
                                new BigDecimal(origQty),
                                8,
                                java.math.RoundingMode.HALF_UP
                        )

                BigDecimal amount =
                        (i < origQty)
                                ? perUnit.setScale(2, java.math.RoundingMode.HALF_UP)
                                : total.subtract(
                                perUnit.multiply(new BigDecimal(origQty - 1))
                        ).setScale(2, java.math.RoundingMode.HALF_UP)

                def newAdj = new HashMap(adj)
                newAdj.amount = amount
                newAdjList.add(newAdj)
            }
//            Assign status
            String statusId
            if (remainingCompleted > 0) {
                statusId = 'ITEM_COMPLETED'
                remainingCompleted--
            } else if (remainingCancelled > 0) {
                statusId = 'ITEM_CANCELLED'
                remainingCancelled--
            } else {
                statusId = 'ITEM_CREATED'
            }

            // ---- FINALIZE ITEM ----
            newItem.quantity = BigDecimal.ONE
            newItem.adjustments = newAdjList
            newItem.statusId = statusId
            newItem.statuses = [[
                                        statusId: statusId,
                                        statusDatetime: ec.user.nowTimestamp,
                                        statusUserLogin: ec.user.userId
                                ]]

            result.add(newItem)
        }

        return result
    }

    }



