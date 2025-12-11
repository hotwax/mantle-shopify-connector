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


}
