package co.hotwax.shopify

import groovy.transform.CompileStatic
import org.moqui.entity.EntityCondition
import org.moqui.entity.EntityList
import org.moqui.entity.EntityValue
import org.moqui.impl.context.ContextJavaUtil
import org.moqui.impl.context.ExecutionContextFactoryImpl
import org.moqui.impl.context.ExecutionContextImpl
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.apache.commons.io.IOUtils

import javax.servlet.*
import javax.servlet.http.HttpServletRequest
import javax.servlet.http.HttpServletResponse

@CompileStatic
class ShopifyWebhookFilter implements Filter {

    protected static final Logger logger = LoggerFactory.getLogger(ShopifyWebhookFilter.class)
    protected FilterConfig filterConfig = null

    ShopifyWebhookFilter() { super() }

    @Override
    void init(FilterConfig filterConfig) {
        this.filterConfig = filterConfig
    }

    @Override
    void doFilter(ServletRequest req, ServletResponse resp, FilterChain chain) {
        if (!(req instanceof HttpServletRequest) || !(resp instanceof HttpServletResponse)) {
            chain.doFilter(req, resp); return
        }

        HttpServletRequest request = (HttpServletRequest) req
        HttpServletResponse response = (HttpServletResponse) resp

        ServletContext servletContext = req.getServletContext()

        ExecutionContextFactoryImpl ecfi = (ExecutionContextFactoryImpl) servletContext.getAttribute("executionContextFactory")
        // check for and cleanly handle when executionContextFactory is not in place in ServletContext attr
        if (ecfi == null) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "System is initializing, try again soon.")
            return
        }

        try {
            // Verify the incoming webhook request
            verifyIncomingWebhook(request, response, ecfi.getEci())
            chain.doFilter(req, resp)
        } catch(Throwable t) {
            logger.error("Error occurred in Shopify Webhook verification", t)
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Error in Shopify webhook verification: ${t.toString()}")
        }
    }

    @Override
    void destroy() {
        // Your implementa tion here }
    }

    void verifyIncomingWebhook(HttpServletRequest request, HttpServletResponse response, ExecutionContextImpl ec) {

        String hmac = request.getHeader("X-Shopify-Hmac-SHA256")
        String shopDomain = request.getHeader("X-Shopify-Shop-Domain")
        String webhookTopic = request.getHeader("X-Shopify-Topic")
        String webhookId = request.getHeader("X-Shopify-Webhook-Id")

        String requestBody = IOUtils.toString(request.getReader());
        if (requestBody.length() == 0) {
            logger.warn("The request body for webhook ${webhookTopic} is empty for Shopify ${shopDomain}, cannot verify webhook")
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "The Request Body is empty for Shopify webhook")
            return
        }
        request.setAttribute("payload", ContextJavaUtil.jacksonMapper.readValue(requestBody, Map.class))


        EntityList systemMessageRemoteList = ec.entityFacade.find("moqui.service.message.SystemMessageRemote")
                .condition("sendUrl", EntityCondition.ComparisonOperator.LIKE, "%"+shopDomain+"%")
                .condition("sendSharedSecret", EntityCondition.ComparisonOperator.NOT_EQUAL, null)
                .disableAuthz().list()
        for (EntityValue systemMessageRemote in systemMessageRemoteList) {
            // Call service to verify Hmac
            Map result = ec.serviceFacade.sync().name("co.hotwax.shopify.webhook.ShopifyWebhookServices.verify#Hmac")
                    .parameters([message:requestBody, hmac:hmac, sharedSecret:systemMessageRemote.sendSharedSecret])
                    .disableAuthz().call()
            // If the hmac matched with the calculatedHmac, break the loop and return
            if (result.isValidWebhook) {
                request.setAttribute("systemMessageRemoteId", systemMessageRemote.systemMessageRemoteId)
                request.setAttribute("webhookId", webhookId)
                request.setAttribute("webhookTopic", webhookTopic)
                return;
            }
        }
        logger.warn("The webhook ${webhookTopic} HMAC header did not match with the computed HMAC for Shopify ${shopDomain}")
        response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "HMAC verification failed for Shopify ${shopDomain} for webhook ${webhookTopic}")
    }
}
