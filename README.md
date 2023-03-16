# mantle-shopify-connector
This moqui runtime component integrates with a subset of Shopify admin APIs to execute OMS integration workflows.

## Shopify Fulfillment API Integration
Set of services to integrate with Shopify Fulfillment API to create Fulfillments in Shopify when the orders are marked as fulfilled in OMS.
This integration works as a batch process where it polls OMS Fulfilled Order Items feed from SFTP and creates outgoing SystemMessage records with respect to each shipment in the feed that creates fulfillment in Shopify.

### Core Services
1. **get#FulfillmentOrders**: Gets fulfillment orders from Shopify for the give shopifyOrderId. This service is called inline by _create#Fulfillment_ to map shopifyLineItemIds with fulfillmentOrderLineItemIds.
2. **create#Fulfillment**: Creates fulfillment in Shopify and returns Shopify FulfillmentId.
3. **consume#FulfillmentFeed**: Consumes OMS fulfilled item feed system message and queues outgoing SystemMessage of type "CreateShopifyFulfillment" with sendNow="true" and sends synchronously in a new transaction.
4. **send#ShopifyFulfillmentSystemMessage**: Send service for "CreateShopifyFulfillment" SystemMessage. Calls _create#Fulfillment_ service to create fulfillment in Shopify.

### Configuration Data
Make sure to setup following configuration data with respect to your environment.
```aidl
<!-- Sftp server connection details for data import -->
<moqui.service.message.SystemMessageRemote systemMessageRemoteId="[Your ID]"
                                           description="SFTP server connection details for data import"
                                           sendUrl="" username="" password=""/>
<!-- Shopify Connection Configuration -->
<moqui.service.message.SystemMessageRemote systemMessageRemoteId="[Your ID]"
                                           description="Shopify Connection Configuration"
                                           sendUrl="https://[shopifyHost]/admin/api/${shopifyApiVersion}" password="[apiToken]"
                                           accessScopeEnumId="SHOP_READ_WRITE_ACCESS"/>

<!-- SystemMessageType record for importing OMS Fulfillment Feed -->
<moqui.service.message.SystemMessageType systemMessageTypeId="OMSFulfillmentFeed"
                                         description="Create OMS Fulfillment Feed System Message"
                                         consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#FulfillmentFeed"
                                         receivePath="" receiveFilePattern=""
                                         receiveResponseEnumId="MsgRrMove" receiveMovePath=""/>

<!-- ServiceJob data for polling OMS Fulfilled Items Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageSftp_OMSFulfillmentFeed" description="Poll OMS Fulfilled Items Feed"
                              serviceName="org.moqui.sftp.SftpMessageServices.poll#SystemMessageSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="OMSFulfillmentFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    <parameters parameterName="consumeSmrId" parameterValue=""/>
</moqui.service.job.ServiceJob>
```
