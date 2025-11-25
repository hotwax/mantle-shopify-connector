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


}
