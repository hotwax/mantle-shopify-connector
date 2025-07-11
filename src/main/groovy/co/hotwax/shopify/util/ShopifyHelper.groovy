package co.hotwax.shopify.util

import org.slf4j.Logger
import org.slf4j.LoggerFactory

class ShopifyHelper {
    protected final static Logger logger = LoggerFactory.getLogger(ShopifyHelper.class)

    public static String resolveShopifyGid(String gid) {
        if (!gid) return null
        return gid.substring(gid.lastIndexOf('/')+1)
    }
    static String sanitizeUrl(String url, boolean secure) {
        if (!url) return null

        // Trim and remove trailing slashes
        url = url.trim().replaceAll('/+$', '')

        // Extract base domain (strip path/query)
        def matcher = url =~ /^(https?:\/\/)?([^\/]+)/
        def baseUrl = matcher ? matcher[0][2] : url

        // Return with https scheme

        return secure?"https://${baseUrl}":baseUrl
    }

}
