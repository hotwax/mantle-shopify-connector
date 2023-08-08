
# mantle-shopify-connector

This moqui runtime component integrates with a subset of Shopify admin APIs to execute OMS integration workflows.

### Global Configuration

This is the global configuration needed for most features in this integration.

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
```

## Shopify Fulfillment API Integration

Set of services and configuration to integrate with Shopify Fulfillment API to create Fulfillments in Shopify when the orders are marked as fulfilled in OMS.  
This integration works as a batch process where it polls OMS Fulfilled Order Items feed from SFTP and creates outgoing SystemMessage records with respect to each shipment in the feed that creates fulfillment in Shopify.

### Core Services

1. **get#FulfillmentOrders**: Gets fulfillment orders from Shopify for the give shopifyOrderId. This service is called inline by _create#Fulfillment_ to map shopifyLineItemIds with fulfillmentOrderLineItemIds.
2. **create#Fulfillment**: Creates fulfillment in Shopify and returns Shopify FulfillmentId.
3. **consume#FulfillmentFeed**: Consumes OMS fulfilled item feed system message and queues outgoing SystemMessage of type "CreateShopifyFulfillment" with sendNow="true" and sends synchronously in a new transaction.
4. **send#ShopifyFulfillmentSystemMessage**: Send service for "CreateShopifyFulfillment" SystemMessage. Calls _create#Fulfillment_ service to create fulfillment in Shopify.
5. **generate#ShopifyFulfillmentAckFeed**: Service to generate shopify fulfillment acknowledgement feed from successfully sent System Messages of type "CreateShopifyFulfillment" and send it to sftp.

### Configuration Data

Make sure to setup following configuration data with respect to your environment.

```aidl
<!-- SystemMessageType record for importing OMS Fulfillment Feed -->
<moqui.service.message.SystemMessageType systemMessageTypeId="OMSFulfillmentFeed"
                                         description="Create OMS Fulfillment Feed System Message"
                                         consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#FulfillmentFeed"
                                         receivePath="" receiveFilePattern=""
                                         receiveResponseEnumId="MsgRrMove" receiveMovePath=""/>

<!-- SystemMessageType record for sending Shopify Fulfillment Ack Feed (sendPath = sftp directory) -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendShopifyFulfillmentAck" description="Send Shopify Fulfillment Ack Feed"
                                         sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
                                         sendPath=""/>

<!-- ServiceJob data for polling OMS Fulfilled Items Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageSftp_OMSFulfillmentFeed" description="Poll OMS Fulfilled Items Feed"
                              serviceName="org.moqui.sftp.SftpMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="OMSFulfillmentFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    <parameters parameterName="consumeSmrId" parameterValue=""/>
</moqui.service.job.ServiceJob>

<!-- ServiceJob data to send Shopify Fulfillment Ack Feed -->
<moqui.service.job.ServiceJob jobName="sendShopifyFulfillmentAckFeed" description="Send Shopify Fulfillment Ack Feed"
                              serviceName="co.hotwax.shopify.fulfillment.ShopifyFulfillmentServices.generate#ShopifyFulfillmentAckFeed" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="sinceDate" parameterValue=""/>
    <parameters parameterName="jobName" parameterValue=""/>
    <parameters parameterName="skipLastRunTimeUpdate" parameterValue=""/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    <parameters parameterName="lastRunTime" parameterValue=""/>
</moqui.service.job.ServiceJob>
```

## Shopify Bulk Import Mutation

Set of services, templates and configuration to integrate with Shopify Bulk Mutation API.  
This integration enables you to configure and poll shopify jsonl feeds from SFTP, stage and upload on shopify and run the intended shopify bulk mutation operation.  
It also polls the running bulk operation status and download and stores the result file locally.
Support for BULK_OPERATION_FINISH webhook will be implemented in next phase.

### Core Services

1. **get#JsonlStagedUploadUrl**: Get staged upload url for jsonl file.
2. **upload#JsonlFileToShopify**: Upload Jsonl file to shopify at staged upload url returned by _get#JsonlStagedUploadUrl_ service.
3. **run#BulkOperationMutation**: Run the mutation defined in 'mutationTemplateLocation' on the jsonl file uploaded at Shopify's 'stageUploadPath'.
4. **get#BulkOperationResult**: Run bulk operation result query to retrieve the result of a Shopify bulk operation.
5. **consume#GraphQLBulkImportFeed**: Consume Bulk Import Feed System Message, upload bulk import feed to Shopify's staged upload url
   and produce corresponding shopify bulk mutation system message.
6. **send#BulkMutationSystemMessage**: Send service to invoke Run Shopify Bulk Operation Mutation API for the System Message.
7. **send#ProducedBulkMutationSystemMessage**: Scheduled service to send next bulk mutation operation in the queue. This service ensures that only one bulk mutation operation runs at a time and bulk mutation system messages are processed sequentially in FIFO manner.
8. **process#BulkOperationResult**: Fetch and process the bulk operations result for a sent system message and create respective incoming
   system message for further processing the result file link.
9. **consume#BulkOperationResult**: Consume service to download and store result file for received bulk operation result system message.
10. **poll#BulkOperationResult**: Polling service to fetch and process bulk operation result for a sent bulk mutation or query system message.

### Configuration Data

Configuration data is mostly specific to the type of jsonl feed and bulk mutation operation to run. It involves bulk mutation templates, SystemMessageType configuration, Enumeration relationship and Service Job data.  
Following are the common templates used,
1. component://shopify-connector/template/graphQL/StagedUploadsCreate.ftl
2. component://shopify-connector/template/graphQL/BulkOperationResultQuery.ftl

Following is the common configuration data,

```aidl
<!-- Parent SystemMessageType for all the shopify bulk import mutation system message types -->
<moqui.service.message.SystemMessageType systemMessageTypeId="ShopifyBulkImport" description="Parent SystemMessageType for Shopify Bulk Imports"/>

<!-- EnumerationType for Shopify system message type enum and relationship -->
<moqui.basic.EnumerationType description="Shopify System Message Type Enum" enumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for polling current bulk operation result -->
<moqui.service.job.ServiceJob jobName="poll_BulkOperationResult_ShopifyBulkImport" description="Poll current bulk operation result"
                              serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.poll#BulkOperationResult" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="parentSystemMessageTypeId" parameterValue="ShopifyBulkImport"/>
</moqui.service.job.ServiceJob>
```

Supported bulk mutations and configuration,

#### Product Tags Update

```aidl
<!-- SystemMessageType record for importing Product Tags Feed -->
<moqui.service.message.SystemMessageType systemMessageTypeId="ProductTagsFeed"
                                         description="Create Product Tags Feed System Message"
                                         consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#GraphQLBulkImportFeed"
                                         receivePath="" receiveResponseEnumId="MsgRrMove" receiveMovePath=""/>

<!-- SystemMessageType record for updating product tags in Shopify -->
<moqui.service.message.SystemMessageType systemMessageTypeId="BulkUpdateProductTags" description="Create Update Product Tags System Message"
                                         parentTypeId="ShopifyBulkImport"
                                         sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkMutationSystemMessage"
                                         sendPath="component://shopify-connector/template/graphQL/BulkUpdateProductTags.ftl"
                                         consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
                                         receivePath="${contentRoot}/hotwax/shopify/ProductTagsFeed/result/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl"/>

<!-- Enumerations for defining relation between two system message types for the purpose of creating consecutive system messages -->
<moqui.basic.Enumeration description="Bulk Update Product Tags" enumId="BulkUpdateProductTags" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Product Tags Feed" enumId="ProductTagsFeed" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="BulkUpdateProductTags" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for polling Product Tags Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageFileSftp_ProductTagsFeed" description="Poll Product Tags Feed"
                              serviceName="co.hotwax.ofbiz.SystemMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="ProductTagsFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    <parameters parameterName="consumeSmrId" parameterValue=""/>
</moqui.service.job.ServiceJob>

<!-- ServiceJob data for sending next bulk mutation system message in queue for shopify bulk import -->
<moqui.service.job.ServiceJob jobName="send_ProducedBulkMutationSystemMessage_ShopifyBulkImport" description="Send next bulk mutation system message in queue for shopify bulk import"
                              serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#ProducedBulkMutationSystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="retryLimit" parameterValue=""/><!-- Defaults to 3 -->
</moqui.service.job.ServiceJob>
```