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

package co.hotwax.shopify.filter


import groovy.transform.CompileStatic
import org.apache.commons.io.IOUtils
import org.moqui.entity.EntityCondition
import org.moqui.entity.EntityList
import org.moqui.entity.EntityValue
import org.moqui.impl.context.ContextJavaUtil
import org.moqui.impl.context.ExecutionContextFactoryImpl
import org.moqui.impl.context.ExecutionContextImpl
import org.slf4j.Logger
import org.slf4j.LoggerFactory

import javax.servlet.Filter
import javax.servlet.FilterChain
import javax.servlet.FilterConfig
import javax.servlet.ServletContext
import javax.servlet.ServletRequest
import javax.servlet.ServletResponse
import javax.servlet.http.HttpServletRequest
import javax.servlet.http.HttpServletResponse

@CompileStatic
class ShopifyRequestFilter implements Filter {

    protected static final Logger logger = LoggerFactory.getLogger(ShopifyRequestFilter.class)
    protected FilterConfig filterConfig = null

    ShopifyRequestFilter() { super() }

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
            // Verify the incoming request
            verifyIncomingRequest(request, response, ecfi.getEci())
            chain.doFilter(req, resp)
        } catch(Throwable t) {
            logger.error("Error occurred in verify shopify request", t)
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Error in Shopify request verification: ${t.toString()}")
        }
    }

    @Override
    void destroy() {
        // Your implementation here }
    }

    void verifyIncomingRequest(HttpServletRequest request, HttpServletResponse response, ExecutionContextImpl ec) {

        String digest = "Base64";
        String hmac = request.getHeader("X-Shopify-Hmac-SHA256")
        String shopDomain = request.getHeader("X-Shopify-Shop-Domain")
        String webhookTopic = request.getHeader("X-Shopify-Topic")
        String webhookId = request.getHeader("X-Shopify-Webhook-Id")
        String pathInfo = request.getPathInfo();
        String requestBody = IOUtils.toString(request.getReader());

        String message = requestBody;
        Map<String, Object> requestQueryParamMap = new TreeMap(org.moqui.util.WebUtilities.simplifyRequestParameters(request, false))
        if (!hmac) {
            //https://shopify.dev/docs/apps/build/online-store/app-proxies/authenticate-app-proxies
            /*
              Added support to verify Shopify requests sent via the Shopify App Proxy.
              This implementation extracts the signature parameters and validates
              the HMAC signature as per Shopify documentation.
             */
            hmac = requestQueryParamMap.remove("signature")
            if (hmac) {
                digest = "Hex"
                // Verify Shopify App Proxy request by validating HMAC signature
                message = requestQueryParamMap
                        .collect { String k, Object v ->
                            if (v instanceof String[]) {
                                return k + "=" + ((String[]) v).join(',')
                            }
                            return k + "=" + String.valueOf(v)
                        }
                        .sort()
                        .join("")
                if (!shopDomain) {
                    shopDomain = requestQueryParamMap.get("shop")
                }
            }
        }

        if (message.length() == 0) {
            logger.warn("The shopify request body is empty for Shopify ${shopDomain}, cannot verify request ${pathInfo}")
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "The request body is empty for Shopify request ${pathInfo}")
            return
        }
        if (requestBody.length() > 0) {
            request.setAttribute("payload", ContextJavaUtil.jacksonMapper.readValue(requestBody, Map.class))
        }
        EntityList systemMessageRemoteList = ec.entityFacade.find("moqui.service.message.SystemMessageRemote")
                .condition("sendUrl", EntityCondition.ComparisonOperator.LIKE, "%"+shopDomain+"%")
                .condition(ec.entity.conditionFactory.makeCondition(
                        ec.entity.conditionFactory.makeCondition("accessScopeEnumId", EntityCondition.ComparisonOperator.NOT_EQUAL, "SHOP_NO_ACCESS"),
                        EntityCondition.OR,
                        ec.entity.conditionFactory.makeCondition("accessScopeEnumId", EntityCondition.ComparisonOperator.IS_NULL, null)))
                .disableAuthz().useCache(true).list()

        for (EntityValue systemMessageRemote in systemMessageRemoteList) {
            // Call service to verify Hmac
            Map result = ec.serviceFacade.sync().name("co.hotwax.shopify.common.ShopifyHelperServices.verify#Hmac")
                    .parameters([message:message, hmac:hmac, sharedSecret:systemMessageRemote.sharedSecret, digest: digest])
                    .disableAuthz().call()
            // TODO: Remove `verifyHmac` with `sendSharedSecret` fallback handling.
            // This is temporary logic for backward compatibility.
            // Once all production instances are updated with the new `SystemMessageRemote` mapping,
            // this fallback should be removed to enforce the new verification flow.
            //===========fallback code start=============
            if (!result.isValidRequest && systemMessageRemote.sendSharedSecret) {
                result = ec.serviceFacade.sync().name("co.hotwax.shopify.common.ShopifyHelperServices.verify#Hmac")
                        .parameters([message:message, hmac:hmac, sharedSecret:systemMessageRemote.sendSharedSecret, digest: digest])
                        .disableAuthz().call()
            }
            //===========fallback code end=============
            if (!result.isValidRequest && systemMessageRemote.oldSharedSecret) {
                result = ec.serviceFacade.sync().name("co.hotwax.shopify.common.ShopifyHelperServices.verify#Hmac")
                        .parameters([message:message, hmac:hmac, sharedSecret:systemMessageRemote.oldSharedSecret, digest: digest])
                        .disableAuthz().call()
            }
            // If the hmac matched with the calculated Hmac, break the loop and return
            if (result.isValidRequest) {
                request.setAttribute("systemMessageRemoteId", systemMessageRemote.systemMessageRemoteId)
                if (webhookId) { request.setAttribute("webhookId", webhookId) }
                if (webhookTopic) { request.setAttribute("webhookTopic", webhookTopic) }
                return;
            }
        }
        logger.warn("The request ${pathInfo} HMAC header did not match with the computed HMAC for Shopify ${shopDomain}")
        response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "HMAC verification failed for Shopify ${shopDomain} request ${pathInfo}")
    }
}