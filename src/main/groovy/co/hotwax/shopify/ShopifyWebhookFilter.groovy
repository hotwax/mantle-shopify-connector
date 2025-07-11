/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

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
                .condition(ec.entity.conditionFactory.makeCondition(
                        ec.entity.conditionFactory.makeCondition("accessScopeEnumId", EntityCondition.ComparisonOperator.NOT_EQUAL, "SHOP_NO_ACCESS"),
                        EntityCondition.OR,
                        ec.entity.conditionFactory.makeCondition("accessScopeEnumId", EntityCondition.ComparisonOperator.IS_NULL, null)))
                .disableAuthz().list()

        for (EntityValue systemMessageRemote in systemMessageRemoteList) {
            // Call service to verify Hmac
            Map result = ec.serviceFacade.sync().name("co.hotwax.shopify.webhook.ShopifyWebhookServices.verify#Hmac")
                    .parameters([message:requestBody, hmac:hmac, sharedSecret:systemMessageRemote.sharedSecret])
                    .disableAuthz().call()
            // TODO: Remove `verifyHmac` with `sendSharedSecret` fallback handling.
            // This is temporary logic for backward compatibility.
            // Once all production instances are updated with the new `SystemMessageRemote` mapping,
            // this fallback should be removed to enforce the new verification flow.
            //===========fallback code start=============
            if (!result.isValidWebhook) {
                result = ec.serviceFacade.sync().name("co.hotwax.shopify.webhook.ShopifyWebhookServices.verify#Hmac")
                        .parameters([message:requestBody, hmac:hmac, sharedSecret:systemMessageRemote.sendSharedSecret])
                        .disableAuthz().call()
            }
            //===========fallback code end=============
            if (!result.isValidWebhook && systemMessageRemote.oldSharedSecret) {
                result = ec.serviceFacade.sync().name("co.hotwax.shopify.webhook.ShopifyWebhookServices.verify#Hmac")
                        .parameters([message:requestBody, hmac:hmac, sharedSecret:systemMessageRemote.oldSharedSecret])
                        .disableAuthz().call()
            }
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