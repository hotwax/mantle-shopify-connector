
# mantle-shopify-connector

This moqui runtime component integrates with a subset of Shopify admin APIs to execute OMS integration workflows.

### Global Configuration

This is the global configuration needed for most features in this integration.

```aidl
<!-- Parent SystemMessageType record for incoming and outgoing local feed file system message types -->
<moqui.service.message.SystemMessageType systemMessageTypeId="LocalFeedFile" description="Local Feed File"/>

<!-- ServiceJob data to purge old SystemMessage records -->
<moqui.service.job.ServiceJob jobName="purge_OldSystemMessages" description="Purge Old System Messages"
        serviceName="co.hotwax.impl.SystemMessageServices.purge#OldSystemMessages" cronExpression="0 0 * * *" paused="Y">
    <parameters parameterName="purgeDays" parameterValue=""/><!-- defaults to 30 days -->
</moqui.service.job.ServiceJob>

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
<!-- Note: By default the sendPath local directory structure is created in runtime://datamanager directory. 
     For using any other directory update the value of mantle.content.root preferenceKey -->
<moqui.service.message.SystemMessageType systemMessageTypeId="OMSFulfillmentFeed"
        description="Create OMS Fulfillment Feed System Message"
        parentTypeId="LocalFeedFile"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#FulfillmentFeed"
        receivePath="/home/${sftpUsername}/hotwax/shopify/FulfilledOrderItems" 
        receiveFilePattern=".*Fulfillment.*\.json"
        receiveResponseEnumId="MsgRrMove" 
        receiveMovePath=""
        sendPath="${contentRoot}/Shopify/OMSFulfillmentFeed">
    <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- SystemMessageType record for sending Shopify Fulfillment Ack Feed (sendPath = sftp directory) -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendShopifyFulfillmentAck" description="Send Shopify Fulfillment Ack Feed"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""
        receivePath="${contentRoot}/shopify/ShopifyFulfillmentAckFeed/ShopifyFulfillmentFeed-${dateTime}.json"/>

<!-- ServiceJob data for polling OMS Fulfilled Items Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageSftp_OMSFulfillmentFeed" description="Poll OMS Fulfilled Items Feed"
        serviceName="org.moqui.sftp.SftpMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="OMSFulfillmentFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
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

## Shopify Bulk Import/Export

Set of services, templates and configuration to integrate with Shopify Bulk Export/Import API.  
This integration enables you,
1. To configure and poll shopify jsonl feeds from SFTP, stage and upload on shopify and run the intended shopify bulk mutation operation.
2. To configure and send shopify bulk queries.

It also polls the running bulk operation status and download and stores the result file locally.
Support for BULK_OPERATION_FINISH webhook will be implemented in next phase.

### Core Services - Common

1. **send#ProducedBulkOperationSystemMessage**: Scheduled service to send next bulk mutation operation in the queue. This service ensures that only one bulk mutation operation runs at a time and bulk mutation system messages are processed sequentially in FIFO manner.
2. **get#BulkOperationResult**: Run bulk operation result query to retrieve the result of a Shopify bulk operation.
3. **process#BulkOperationResult**: Fetch and process the bulk operations result for a sent system message and create respective incoming
   system message for further processing the result file link.
4. **consume#BulkOperationResult**: Consume service to download and store result file for received bulk operation result system message.
5. **poll#BulkOperationResult**: Polling service to fetch and process bulk operation result for a sent bulk mutation or query system message.

### Core Services - Mutation

1. **get#JsonlStagedUploadUrl**: Get staged upload url for jsonl file.
2. **upload#JsonlFileToShopify**: Upload Jsonl file to shopify at staged upload url returned by _get#JsonlStagedUploadUrl_ service.
3. **run#BulkOperationMutation**: Run the mutation defined in 'mutationTemplateLocation' on the jsonl file uploaded at Shopify's 'stageUploadPath'.
5. **consume#GraphQLBulkImportFeed**: Consume Bulk Import Feed System Message, upload bulk import feed to Shopify's staged upload url
   and produce corresponding shopify bulk mutation system message.
6. **send#BulkMutationSystemMessage**: Send service to invoke Run Shopify Bulk Operation Mutation API for the System Message.

### Core Services - Query

1. **run#BulkOperationQuery**: Run the bulk query defined in 'queryTemplateLocation' with optional filter query.
2. **queue#BulkQuerySystemMessage**: Scheduled service to queue a bulk query system message of a specific SystemMessageType.
3. **send#BulkQuerySystemMessage**: Send service to invoke Run Shopify Bulk Operation Query API for the System Message.

### Configuration Data - Mutation

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

<!-- ServiceJob data for sending next bulk mutation system message in queue for shopify bulk import -->
<moqui.service.job.ServiceJob jobName="send_ProducedBulkMutationSystemMessage_ShopifyBulkImport" description="Send next bulk mutation system message in queue for shopify bulk import"
        serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#ProducedBulkMutationSystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="retryLimit" parameterValue=""/><!-- Defaults to 3 -->
</moqui.service.job.ServiceJob>

<!-- ServiceJob data for polling current bulk operation result -->
<moqui.service.job.ServiceJob jobName="poll_BulkOperationResult_ShopifyBulkImport" description="Poll current bulk operation result"
        serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.poll#BulkOperationResult" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="parentSystemMessageTypeId" parameterValue="ShopifyBulkImport"/>
    <parameters parameterName="consumeSmrId" parameterValue=""/><!-- For sending the result file to SFTP server -->
</moqui.service.job.ServiceJob>
```

Supported bulk mutations and configuration,

#### Product Tags Update

```aidl
<!-- SystemMessageType record for importing Product Tags Feed -->
<moqui.service.message.SystemMessageType systemMessageTypeId="ProductTagsFeed"
        description="Create Product Tags Feed System Message"
        parentTypeId="LocalFeedFile"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#GraphQLBulkImportFeed"
        receivePath="" receiveResponseEnumId="MsgRrMove" receiveMovePath=""
        sendPath="${contentRoot}/Shopify/ProductTagsFeed"/>

<!-- SystemMessageType record for updating product tags in Shopify -->
<moqui.service.message.SystemMessageType systemMessageTypeId="BulkUpdateProductTags" description="Create Update Product Tags System Message"
        parentTypeId="ShopifyBulkImport"
        sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkMutationSystemMessage"
        sendPath="component://shopify-connector/template/graphQL/BulkUpdateProductTags.ftl"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
        receivePath="${contentRoot}/hotwax/shopify/ProductTagsFeed/result/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
    <paramters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- SystemMessageType record for sending bulk update product tags result to SFTP -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkUpdateProductTagsResult"
        description="Send Bulk Update Product Tags Result"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""/>

<!-- Enumerations for defining relation between two system message types for the purpose of creating consecutive system messages -->
<moqui.basic.Enumeration description="Send Bulk Update Product Tags Result" enumId="SendBulkUpdateProductTagsResult" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Bulk Update Product Tags" enumId="BulkUpdateProductTags" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkUpdateProductTagsResult" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Product Tags Feed" enumId="ProductTagsFeed" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="BulkUpdateProductTags" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for polling Product Tags Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageFileSftp_ProductTagsFeed" description="Poll Product Tags Feed"
      serviceName="co.hotwax.ofbiz.SystemMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="ProductTagsFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
</moqui.service.job.ServiceJob>
```

#### Product Variants Update

```aidl
<!-- SystemMessageType record for importing Product Varaints Feed -->
<moqui.service.message.SystemMessageType systemMessageTypeId="ProductVariantsFeed"
        description="Create Product Variants Feed System Message"
        parentTypeId="LocalFeedFile"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#GraphQLBulkImportFeed"
        receivePath="" receiveResponseEnumId="MsgRrMove" receiveMovePath=""
        sendPath="${contentRoot}/Shopify/ProductVariantsFeed"/>

<!-- SystemMessageType record for updating product variants in Shopify -->
<moqui.service.message.SystemMessageType systemMessageTypeId="BulkUpdateProductVariants" description="Create Update Product Variants System Message"
        parentTypeId="ShopifyBulkImport"
        sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkMutationSystemMessage"
        sendPath="component://shopify-connector/template/graphQL/BulkUpdateProductTags.ftl"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
        receivePath="${contentRoot}/hotwax/shopify/ProductVariantsFeed/result/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
    <paramters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- Additional paramter configuration, a comma seprated values of namespaces -->
<moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="BulkUpdateProductVariants"
        parameterName="namespaces" parameterValue="" systemMessageRemoteId=""/>

<!-- SystemMessageType record for sending bulk update product variants result to SFTP -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkUpdateProductVariantsResult"
        description="Send Bulk Update Product Variants Result"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""/>

<!-- Enumerations for defining relation between two system message types for the purpose of creating consecutive system messages -->
<moqui.basic.Enumeration description="Send Bulk Update Product Variants Result" enumId="SendBulkUpdateProductVariantsResult" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Bulk Update Product Variants" enumId="BulkUpdateProductVariants" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkUpdateProductVariantsResult" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Product Variants Feed" enumId="ProductVariantsFeed" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="BulkUpdateProductVariants" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for polling Product Variants Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageFileSftp_ProductVariantsFeed" description="Poll Product Variants Feed"
      serviceName="co.hotwax.ofbiz.SystemMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="ProductVariantsFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
</moqui.service.job.ServiceJob>
```

#### Gift Card Create

```aidl
<!-- SystemMessageType record for importing Gift Card Activation Feed -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="GiftCardActivationFeed"
            description="Create Gift Card Activation Feed System Message"
            parentTypeId="LocalFeedFile"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#GraphQLBulkImportFeed"
            receivePath=""
            receiveResponseEnumId="MsgRrMove"
            receiveMovePath=""
            sendPath="${contentRoot}/shopify/GiftCardActivationFeed">
        <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>

    <!-- SystemMessageType record for creating/activating gift cards in Shopify -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="BulkCreateGiftCards"
            description="Bulk Create Gift Cards System Message"
            parentTypeId="ShopifyBulkImport"
            sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkMutationSystemMessage"
            sendPath="component://shopify-connector/template/graphQL/BulkCreateGiftCards.ftl"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
            receivePath="${contentRoot}/shopify/GiftCardActivationFeed/result/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
        <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>
    
    <!-- SystemMessageType record for sending bulk create gift cards result to SFTP -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkCreateGiftCardsResult"
            description="Send Bulk Create Gift Card Result"
            parentTypeId="LocalFeedFile"
            sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
            sendPath=""/>

    <!-- Enumeration to create relation between GiftCardActivationFeed, BulkCreateGiftCards and SendBulkCreateGiftCardsResult SystemMessageType(s) -->
    <moqui.basic.Enumeration description="Send Bulk Update Product Variants Result" enumId="SendBulkCreateGiftCardsResult" enumTypeId="ShopifyMessageTypeEnum"/>
    <moqui.basic.Enumeration description="Bulk Create Gift Cards" enumId="BulkCreateGiftCards" enumTypeId="ShopifyMessageTypeEnum" relatedEnumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkCreateGiftCardsResult"/>
    <moqui.basic.Enumeration description="Gift Card Activation Feed" enumId="GiftCardActivationFeed" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="BulkCreateGiftCards" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

    <!-- ServiceJob data for polling Gift Card Activation Feed -->
    <moqui.service.job.ServiceJob jobName="poll_SystemMessageFileSftp_GiftCardActivationFeed" description="Poll Gift Card Activation Feed"
            serviceName="co.hotwax.ofbiz.SystemMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
        <parameters parameterName="systemMessageTypeId" parameterValue="GiftCardActivationFeed"/>
        <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    </moqui.service.job.ServiceJob>
```

### Configuration Data - Query

Following is the common configuration data,

```aidl
<!-- Parent SystemMessageType for all the shopify bulk query system message types -->
<moqui.service.message.SystemMessageType systemMessageTypeId="ShopifyBulkQuery" description="Parent SystemMessageType for Shopify Bulk Query"/>

<!-- ServiceJob data for sending next bulk query system message in queue-->
<moqui.service.job.ServiceJob jobName="send_ProducedBulkOperationSystemMessage_ShopifyBulkQuery" description="Send next bulk query system message in queue"
        serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#ProducedBulkOperationSystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="parentSystemMessageTypeId" parameterValue="ShopifyBulkQuery"/>
    <parameters parameterName="retryLimit" parameterValue=""/><!-- Defaults to 3 -->
</moqui.service.job.ServiceJob>

<!-- ServiceJob data for polling current bulk operation query result -->
<moqui.service.job.ServiceJob jobName="poll_BulkOperationResult_ShopifyBulkQuery" description="Poll current bulk operation query result"
        serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.poll#BulkOperationResult" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="parentSystemMessageTypeId" parameterValue="ShopifyBulkQuery"/>
    <parameters parameterName="consumeSmrId" parameterValue=""/><!-- For sending the result file to SFTP server -->
</moqui.service.job.ServiceJob>
```

Supported bulk queries and configuration,

You could configure following default parameters and any additional parameters as required w.r.t. each query SystemMessageType, these parameters would be available to render your query template.

```aidl
<!-- Additional paramter configuration, a comma seprated values of namespaces -->
<moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="[systemMessageTypeId]"
        parameterName="namespaces" parameterValue="" systemMessageRemoteId=""/>

<!-- Additional paramter configuration, default filter query -->
<moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="[systemMessageTypeId]"
        parameterName="fiterQuery" parameterValue="" systemMessageRemoteId=""/>

<!-- Additional parameter configuration, time buffers for fromDate and thruDate, must be an integer value for minutes -->
<moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="[systemMessageTypeId]"
        parameterName="fromDateBuffer" parameterValue="" systemMessageRemoteId=""/>
<moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="[systemMessageTypeId]"
        parameterName="thruDateBuffer" parameterValue="" systemMessageRemoteId=""/>
```

#### Bulk Variants Metafield Query

```aidl
<!-- SystemMessageType record for bulk variant metafield query to Shopify -->
<moqui.service.message.SystemMessageType systemMessageTypeId="BulkVariantsMetafieldQuery" description="Bulk Variants Metafield Query System Message"
        parentTypeId="ShopifyBulkQuery"
        sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkQuerySystemMessage"
        sendPath="component://shopify-connector/template/graphQL/BulkVariantsMetafieldQuery.ftl"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
        receivePath="${contentRoot}/hotwax/shopify/BulkVariantsMetafieldFeed/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
    <paramters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- SystemMessageType record for sending bulk variants metafield query result to SFTP -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkVariantsMetafieldQueryResult"
        description="Send Bulk Variants Metafield Query Result"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""/>

<!-- Enumerations for defining relation between two system message types for the purpose of creating consecutive system messages -->
<moqui.basic.Enumeration description="Send Bulk Variants Metafield Query Result" enumId="SendBulkVariantsMetafieldQueryResult" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Bulk Variants Metafield Query" enumId="BulkVariantsMetafieldQuery" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkVariantsMetafieldQueryResult" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for queuing bulk variants metafield query -->
<moqui.service.job.ServiceJob jobName="queue_BulkQuerySystemMessage_BulkVariantsMetafieldQueryt" description="Queue bulk variants metafield query"
        serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.queue#BulkQuerySystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="BulkVariantsMetafieldQuery"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    <parameters parameterName="filterQuery" parameterValue=""/>
    <parameters parameterName="fromDate" parameterValue=""/>
    <parameters parameterName="thruDate" parameterValue=""/>
</moqui.service.job.ServiceJob>
```

#### Bulk Order Metafields Query

```aidl
<!-- SystemMessageType record for bulk order metafields query to Shopify -->
<moqui.service.message.SystemMessageType systemMessageTypeId="BulkOrderMetafieldsQuery" description="Bulk Order Metafields Query System Message"
        parentTypeId="ShopifyBulkQuery"
        sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkQuerySystemMessage"
        sendPath="component://shopify-connector/template/graphQL/BulkOrderMetafieldsQuery.ftl"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
        receivePath="${contentRoot}/hotwax/shopify/BulkOrderMetafieldsFeed/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
    <paramters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- SystemMessageType record for sending bulk order metafields query result to SFTP -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkOrderMetafieldsQueryResult"
        description="Send Bulk Order Metafields Query Result"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""/>

<!-- Enumerations for defining relation between two system message types for the purpose of creating consecutive system messages -->
<moqui.basic.Enumeration description="Send Bulk Order Metafields Query Result" enumId="SendBulkOrderMetafieldsQueryResult" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Bulk Order Metafields Query" enumId="BulkOrderMetafieldsQuery" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkOrderMetafieldsQueryResult" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for queuing bulk order metafields query -->
<moqui.service.job.ServiceJob jobName="queue_BulkQuerySystemMessage_BulkOrderMetafieldsQuery" description="Queue bulk order metafields query"
        serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.queue#BulkQuerySystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="BulkOrderMetafieldsQuery"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    <parameters parameterName="filterQuery" parameterValue=""/>
    <parameters parameterName="fromDate" parameterValue=""/>
    <parameters parameterName="thruDate" parameterValue=""/>
</moqui.service.job.ServiceJob>
```

#### Bulk Order Headers Query

```aidl
    <!-- SystemMessageType record for bulk order headers query to Shopify -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="BulkOrderHeadersQuery"
            description="Bulk Order Headers Query System Message"
            parentTypeId="ShopifyBulkQuery"
            sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkQuerySystemMessage"
            sendPath="component://shopify-connector/template/graphQL/BulkOrderHeadersQuery.ftl"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
            receivePath="${contentRoot}/shopify/BulkOrderHeadersQuery/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
        <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>

    <!-- SystemMessageType record for sending bulk order headers query result to SFTP -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkOrderHeadersQueryResult"
            description="Send Bulk Order Headers Query Result"
            parentTypeId="LocalFeedFile"
            sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
            sendPath=""/>

    <!-- Enumeration to create relation between BulkOrderHeadersQuery and SendBulkOrderHeadersQueryResult SystemMessageType(s) -->
    <moqui.basic.Enumeration description="Send Bulk Order Headers Query Result" enumId="SendBulkOrderHeadersQueryResult" enumTypeId="ShopifyMessageTypeEnum"/>
    <moqui.basic.Enumeration description="Bulk Order Headers Query" enumId="BulkOrderHeadersQuery" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkOrderHeadersQueryResult" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

    <!-- ServiceJob data for queuing bulk order headers query -->
    <moqui.service.job.ServiceJob jobName="queue_BulkQuerySystemMessage_BulkOrderHeadersQuery" description="Queue bulk order headers query"
            serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.queue#BulkQuerySystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
        <parameters parameterName="systemMessageTypeId" parameterValue="BulkOrderHeadersQuery"/>
        <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
        <parameters parameterName="filterQuery" parameterValue=""/>
        <parameters parameterName="fromDate" parameterValue=""/>
        <parameters parameterName="thruDate" parameterValue=""/>
        <parameters parameterName="fromDateLabel" parameterValue=""/>
        <parameters parameterName="thruDateLabel" parameterValue=""/>
    </moqui.service.job.ServiceJob>
```

### Bulk Order Items Query

```aidl
    <!-- SystemMessageType record for bulk order items query to Shopify -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="BulkOrderItemsQuery"
            description="Bulk Order Items Query System Message"
            parentTypeId="ShopifyBulkQuery"
            sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkQuerySystemMessage"
            sendPath="component://shopify-connector/template/graphQL/BulkOrderItemsQuery.ftl"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
            receivePath="${contentRoot}/shopify/BulkOrderItemsQuery/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
        <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>

    <!-- SystemMessageType record for sending bulk order items query result to SFTP -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkOrderItemsQueryResult"
            description="Send Bulk Order Items Query Result"
            parentTypeId="LocalFeedFile"
            sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
            sendPath=""/>

    <!-- Enumeration to create relation between BulkOrderItemsQuery and SendBulkOrderItemsQueryResult SystemMessageType(s) -->
    <moqui.basic.Enumeration description="Send Bulk Order Items Query Result" enumId="SendBulkOrderItemsQueryResult" enumTypeId="ShopifyMessageTypeEnum"/>
    <moqui.basic.Enumeration description="Bulk Order Items Query" enumId="BulkOrderItemsQuery" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkOrderItemsQueryResult" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

    <!-- ServiceJob data for queuing bulk updated order items query -->
    <moqui.service.job.ServiceJob jobName="queue_BulkQuerySystemMessage_BulkOrderItemsQuery" description="Queue bulk order items query"
            serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.queue#BulkQuerySystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
        <parameters parameterName="systemMessageTypeId" parameterValue="BulkOrderItemsQuery"/>
        <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
        <parameters parameterName="filterQuery" parameterValue=""/>
        <parameters parameterName="fromDate" parameterValue=""/>
        <parameters parameterName="thruDate" parameterValue=""/>
        <parameters parameterName="fromDateLabel" parameterValue=""/>
        <parameters parameterName="thruDateLabel" parameterValue=""/>
    </moqui.service.job.ServiceJob>
```

### Bulk Order Custom Attributes Query

```aidl
<!-- SystemMessageType record for bulk order custom attributes query to Shopify -->
<moqui.service.message.SystemMessageType systemMessageTypeId="BulkOrderCustomAttributesQuery"
        description="Bulk Order Custom Attributes Query System Message"
        parentTypeId="ShopifyBulkQuery"
        sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkQuerySystemMessage"
        sendPath="component://shopify-connector/template/graphQL/BulkOrderCustomAttributesQuery.ftl"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
        receivePath="${contentRoot}/shopify/BulkOrderCustomAttributesQuery/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
    <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- SystemMessageType record for sending bulk order custom attributes query result to SFTP -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendBulkOrderCustomAttributesQueryResult"
        description="Send Bulk Order Custom Attributes Query Result"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""/>

<!-- Enumeration to create relation between BulkOrderCustomAttributesQuery and SendBulkOrderCustomAttributesQueryResult SystemMessageType(s) -->
<moqui.basic.Enumeration description="Send Bulk Order Custom Attributes Query Result" enumId="SendBulkOrderCustomAttributesQueryResult" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Bulk Order Custom Attributes Query" enumId="BulkOrderCustomAttributesQuery" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendBulkOrderCustomAttributesQueryResult" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
    
<!-- ServiceJob data for queuing bulk order custom attributes query -->
<moqui.service.job.ServiceJob jobName="queue_BulkQuerySystemMessage_BulkOrderCustomAttributesQuery" description="Queue bulk order custom attributes query"
        serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.queue#BulkQuerySystemMessage" cronExpression="0 0/15 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="BulkOrderCustomAttributesQuery"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
    <parameters parameterName="filterQuery" parameterValue=""/>
    <parameters parameterName="fromDate" parameterValue=""/>
    <parameters parameterName="thruDate" parameterValue=""/>
    <parameters parameterName="fromDateLabel" parameterValue=""/>
    <parameters parameterName="thruDateLabel" parameterValue=""/>
</moqui.service.job.ServiceJob>
```

## Shopify Webhook Integration

Set of services and configuration to integrate with Shopify Webhook GraphQL API.  
This integration enables you to configure a shopify webhook topic, subscribe/unsubscribe to it, receive payload from the subscribed webhook topic and consume the payload to further process it.

### Webhook Filter

**co.hotwax.shopify.ShopifyWebhookFilter**: A filter to verify HMAC for all incoming webhook payloads and set the required attributes on HTTP request upon successful verification.

#### Configuration

Folliowing configuration is added to MoquiConf.xml,  

```aidl
<default-property name="shopify_webhook_end_point" value="/rest/s1/shopify/webhook/payload"/>

<webapp-list>
    <webapp name="webroot">
        <!-- Shopify Webhook Request Filter  -->
        <filter name="ShopifyWebhookFilter" class="co.hotwax.shopify.ShopifyWebhookFilter" async-supported="true">
            <url-pattern>/rest/s1/shopify/webhook/*</url-pattern>
        </filter>
    </webapp>
</webapp-list>
```
### Core Services

1. **create#WebhookSubscription**: Subscribe to shopify webhook topic with your apps callbackUrl (end point).
2. **get#WebhookSubscriptions**: Get a list of all subscribed webhooks filtered by query parameters.
3. **delete#WebhookSubscription**: Unsubscribe a specific webhook topic.
4. **verify#Hmac**: Verify hmac for the received webhook payload.
5. **receive#WebhookPayload**: Receive webhook payload in an incoming SystemMessage of the webhook topics SystemMessageType.
6. **queue#WebhookSubscriptionSystemMessage**: Service to initiate webhook subscription of a specific type by creating a system message.
7. **send#WebhookSubscriptionSystemMessage**: Send service to invoke Create Webhook Subscription API for the System Message.
8. **queue#WebhookSubscriptionDeleteSystemMessage**: Service to initiate delete webhook subscription of a specific type by creating a system message.
9. **send#WebhookSubscriptionDeleteSystemMessage**: Send service to invoke Delete Webhook Subscription API for the System Message. This service first get the webhookSubscriptionId for specified webhook topic and registered callbackUrl and the invokes Delete Webhook Subscription API for the webhookSubscriptionId.
10. **consume#WebhookPayloadSystemMessage**: Generic service to consume shopify webhook payload and generate multiple incoming or outgoing system messages for further processing.

### Subscribing a Webhook Topic

1. Following is some global configuration data for webhook subscriptions,
    ```aidl
    <!-- Parent SystemMessageType for all the shopify webhook system message types --> 
    <moqui.service.message.SystemMessageType systemMessageTypeId="ShopifyWebhook"
            description="Parent SystemMessageType for Shopify Webhooks"/>

    <!-- EnumerationType for Shopify webhook topic mapping to webhook system message type -->
    <moqui.basic.EnumerationType description="Shopify Webhook Enum" enumTypeId="ShopifyWebhookEnum"/>
    ```
2. Implement a consume service as needed to process webhook payload. In absence of a conusme service, the payload would just be saved as is in an incoming SystemMessage.
3. To subscribe a webhook you need to define following configuration data,
    ```aidl
    <!-- SystemMessageType record for shopify webhook -->
    <moqui.service.message.SystemMessageType systemMessageTypeId=""
            description=""
            parentTypeId="ShopifyWebhook"
            sendServiceName="co.hotwax.shopify.webhook.ShopifyWebhookServices.send#WebhookSubscriptionSystemMessage"
            sendPath="component://shopify-connector/template/graphQL/WebhookSubscriptionCreate.ftl"
            consumeServiceName="[consume service to process webhook payload]">
        <parameters parameterName="topic" parameterValue="[GraphQL Webhook Topic]" systemMessageRemoteId=""/>
        <!-- Optional, defaluts to "/rest/s1/shopify/webhook/payload"  -->
        <parameters parameterName="endpoint" parameterValue="" systemMessageRemoteId=""/>
        <!-- Additional configuration when using generic _consume#WebhookPayloadSystemMessage_ service to generate multiple incoming or outgoing system messages -->
        <parameters parameterName="incomingSystemMessageParamList" parameterValue="[{'systemMessageTypeId':'', systemMessageRemoteId:''},.....]" systemMessageRemoteId=""/>
        <parameters parameterName="outgoingSystemMessageParamList" parameterValue="[{'systemMessageTypeId':'', systemMessageRemoteId:'', 'sendNow':''},.....]" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>

    <moqui.basic.Enumeration description="" enumId="[systemMessageTypeId of webhook]"
            enumTypeId="ShopifyMessageTypeEnum" enumCode="[Shopify Webhook Topic]"/> (https://shopify.dev/docs/api/admin-rest/2023-10/resources/webhook#event-topics)
    ```
4. To subscribe to the webhook invoke _queue#WebhookSubscriptionSystemMessage_ service.

### Unsubscribing a Webhook Topic

1. Following is the configuration data for deleting any webhook subscription,
    ```aidl
    <!-- SystemMessageTypeRecord for deleting a specific webhook subscription -->
    <moqui.service.message.SystemMessageType systemMessageTypeId="DeleteWebhookSubscription"
            description="Delete Shopify Webhook Subscription"
            sendServiceName="co.hotwax.shopify.webhook.ShopifyWebhookServices.send#WebhookSubscriptionDeleteSystemMessage"
            sendPath="component://shopify-connector/template/graphQL/WebhookSubscriptionDelete.ftl">
        <parameters parameterName="queryTemplateLocation" parameterValue="component://shopify-connector/template/graphQL/WebhookSubscriptionsQuery.ftl" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>
    ```
2. To unsubscribe webhook invoke _queue#WebhookSubscriptionDeleteSystemMessage_ service.

### Supported Shopify Webhooks

#### Bulk Operations Finish (bulk_operations/finish)

```aidl
<!-- SystemMessageType record for shopify BULK_OPERATION_FINISH webhook -->
<moqui.service.message.SystemMessageType systemMessageTypeId="BulkOperationsFinish"
        description="Shopify Bulk Operations Finish Webhook"
        parentTypeId="ShopifyWebhook"
        sendServiceName="co.hotwax.shopify.webhook.ShopifyWebhookServices.send#WebhookSubscriptionSystemMessage"
        sendPath="component://shopify-connector/template/graphQL/WebhookSubscriptionCreate.ftl"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationsFinishWebhookPayload">
    <parameters parameterName="topic" parameterValue="BULK_OPERATIONS_FINISH" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- Enumeration for mapping BulkOperationsFinish SystemMessageType to bulk_operations/finish shopify webhook topic -->
<moqui.basic.Enumeration description="Shopify Bulk Operation Finish Webhook" enumId="BulkOperationsFinish"
        enumTypeId="ShopifyMessageTypeEnum" enumCode="bulk_operations/finish"/>
```

#### Orders Updated (orders/updated)

```aidl
<!-- SystemMessageType record for shopify ORDERS_UPDATED webhook -->
<moqui.service.message.SystemMessageType systemMessageTypeId="OrdersUpdated"
        description="Shopify Orders Updated Webhook"
        parentTypeId="ShopifyWebhook"
        sendServiceName="co.hotwax.shopify.webhook.ShopifyWebhookServices.send#WebhookSubscriptionSystemMessage"
        sendPath="component://shopify-connector/template/graphQL/WebhookSubscriptionCreate.ftl"
        consumeServiceName="co.hotwax.shopify.webhook.ShopifyWebhookServices.consume#WebhookPayloadSystemMessage">
    <parameters parameterName="topic" parameterValue="ORDERS_UPDATED" systemMessageRemoteId=""/>
    <parameters parameterName="outgoingSystemMessageParamList" parameterValue="[{'systemMessageTypeId':'QueueOrderUpdatedAt','sendNow':'true'}]" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- Enumeration for mapping OrderUpdated SystemMessageType to orders/updated shopify webhook topic -->
<moqui.basic.Enumeration description="Shopify Bulk Operation Finish Webhook" enumId="OrdersUpdated"
        enumTypeId="ShopifyMessageTypeEnum" enumCode="orders/updated"/>

<moqui.service.message.SystemMessageType systemMessageTypeId="QueueOrderUpdatedAt"
        description="Send Order Update At Date to SQS Queue"
        sendServiceName="co.hotwax.shopify.order.ShopifyOrderServices.send#OrderUpdatedAtToQueue"
        sendPath="[queueUrl]"/>
```

## Shopify Refund/Return API Integration

Set of services and configurations to integrate with Shopify GraphQL Refund/Return API.

### Core Services
1. **get#ReturnLineItemsByRefund**: Integrates with Shopify GraphQL Refund API to return a list of return line items.
2. **get#RefundLineItems**: Integrates with Shopify GraphQL Refund API to get associated refund line items.

### Supported flows

#### Get return reason for synced refunds

This flow aims to fetch the return reasons associated to return line items for a refund.  
It polls an SFTP server to read a json file containing list of Shopify refundIds. For this list it fetches return reasons for each refund and pushes the return reason json feed to SFTP.  
Related configurations,

```aidl
<!-- SystemMessageType record for importing OMS Synced Refunds Feed -->
<moqui.service.message.SystemMessageType systemMessageTypeId="OMSSyncedRefundsFeed"
        description="Create OMS Synced Refunds Feed System Message"
        parentTypeId="LocalFeedFile"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#SyncedRefundsFeed"
        receivePath=""
        receiveResponseEnumId="MsgRrMove"
        receiveMovePath=""
        sendPath="${contentRoot}/shopify/SyncedRefundsFeed">
    <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- SystemMessageType record for sending Shopify Return Reason Feed (sendPath = sftp directory) -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendShopifyReturnReasonFeed"
        description="Send Shopify Return Reason Feed"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""
        receivePath="${contentRoot}/shopify/ShopifyReturnReasonFeed/ShopifyReturnReasonFeed-${dateTime}.json"/>

<!-- Enumeration to create relation between OMSSyncedRefundsFeed and SendShopifyReturnReasonFeed SystemMessageType(s) -->
<moqui.basic.Enumeration description="Send Bulk Order Custom Attributes Query Result" enumId="SendShopifyReturnReasonFeed" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Bulk Order Custom Attributes Query" enumId="OMSSyncedRefundsFeed" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendShopifyReturnReasonFeed" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for polling OMS Synced Refunds Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageFileSftp_OMSSyncedRefundsFeed" description="Poll OMS Synced Refunds Feed"
        serviceName="co.hotwax.ofbiz.SystemMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="OMSSyncedRefundsFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
</moqui.service.job.ServiceJob>
```

## Shopify Order API Integration

Set of services and configurations to integrate with Shopify GraphQL Order API.

### Core Services
1. **get#OrderMetafields**: Integrates with Shopify GraphQL Order API to return metafields for a given shopify orderId and namespace (optional).

### Supported flows

#### Get order metafields for an orderIds feed

This flow aims to fetch the metafields for an order in given namespaces (optional).  
It polls an SFTP server to read a json file containing list of Shopify orderIds. For this list it fetches metafields for each order in given namespaces and pushes the order metafields json feed to SFTP.  
Related configurations,

```aidl
<!-- SystemMessageType record for importing Order Ids Feed -->
<moqui.service.message.SystemMessageType systemMessageTypeId="OrderIdsFeed"
        description="Create Order Ids Feed System Message"
        parentTypeId="LocalFeedFile"
        consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#OrderIdsFeed"
        receivePath=""
        receiveResponseEnumId="MsgRrMove"
        receiveMovePath=""
        sendPath="${contentRoot}/shopify/OrderIdsFeed">
    <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<moqui.service.message.SystemMessageType systemMessageTypeId="GenerateOrderMetafieldsFeed"
        description="Generate Order Metafields Feed For Orders Feed"
        sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.generate#OrderMetafieldsFeed"
        sendPath="${contentRoot}/shopify/OrderMetafieldsFeed/OrderMetafieldsFeed-${dateTime}.json">
    <parameters parameterName="namespaces" parameterValue="" systemMessageRemoteId=""/>
    <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
</moqui.service.message.SystemMessageType>

<!-- SystemMessageType record for sending Order Metafields Feed (sendPath = sftp directory) -->
<moqui.service.message.SystemMessageType systemMessageTypeId="SendOrderMetafieldsFeed"
        description="Send Order Metafields Feed"
        parentTypeId="LocalFeedFile"
        sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
        sendPath=""/>

<!-- Enumeration to create relation between OrderIdsFeed, GenerateOrderMetafieldsFeed and SendOrderMetafieldsFeed SystemMessageType(s) -->
<moqui.basic.Enumeration description="Send Order Metafields Feed" enumId="SendOrderMetafieldsFeed" enumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Generate Order Metafields Feed" enumId="GenerateOrderMetafieldsFeed" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendOrderMetafieldsFeed" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
<moqui.basic.Enumeration description="Order Ids Feed" enumId="OrderIdsFeed" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="GenerateOrderMetafieldsFeed" relatedEnumTypeId="ShopifyMessageTypeEnum"/>

<!-- ServiceJob data for polling OMS Order Ids Feed -->
<moqui.service.job.ServiceJob jobName="poll_SystemMessageFileSftp_OMSOrderIdsFeed" description="Poll OMS Order Ids Feed"
        serviceName="co.hotwax.ofbiz.SystemMessageServices.poll#SystemMessageFileSftp" cronExpression="0 0 * * * ?" paused="Y">
    <parameters parameterName="systemMessageTypeId" parameterValue="OrderIdsFeed"/>
    <parameters parameterName="systemMessageRemoteId" parameterValue=""/>
</moqui.service.job.ServiceJob>
```