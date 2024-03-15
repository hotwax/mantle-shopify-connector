1. Update the instance with the data load command to load the upgrade data only. 
2. Follow the "Upgrade Steps" added below. 
3. Follow the client specific manual if any. 
4. Check the transformations and Nifi flows if configured and requires an update.

## Upgrade Steps
### Gift Card Activation Feed
1. GiftCardActivationFeed SystemMessageType record for importing Gift Card Activation Feed.
   1. Add shop specific SystemMessageType data taking reference from the template GiftCardActivationFeed SystemMessageType.
   2. Check and update the receiveFilePattern as required based on the shopId alone or combination of shop Id and product Store Id.
       - Sample data
       - NOTE: add the value for parameterValue and systemMessageRemoteId as per new setup.
    ```xml
    <moqui.service.message.SystemMessageType systemMessageTypeId="GiftCardActivationFeed_{shopId_storeId}"
            description="Create Gift Card Activation Feed System Message"
            parentTypeId="LocalFeedFile"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#GraphQLBulkImportFeed"
            receiveFilePattern=".*{shop_id/store_id}.*.json" 
            receivePath="/home/${sftpUsername}/hotwax/shopify/GiftCardActivationFeed"
            receiveResponseEnumId="MsgRrMove"
            receiveMovePath="/home/${sftpUsername}/hotwax/shopify/GiftCardActivationFeed/archive"
            sendPath="${contentRoot}/shopify/GiftCardActivationFeed">
        <parameters parameterName="consumeSmrId" parameterValue="{shopify_remote}" systemMessageRemoteId="RemoteSftp"/>
    </moqui.service.message.SystemMessageType>
    ```

2. SystemMessageType for BulkCreateGiftCards
   1. Ensure loading this system message type data
    ```xml
    <moqui.service.message.SystemMessageType systemMessageTypeId="BulkCreateGiftCards"
            description="Bulk Create Gift Cards System Message"
            parentTypeId="ShopifyBulkImport"
            sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.send#BulkMutationSystemMessage"
            sendPath="component://shopify-connector/template/graphQL/BulkCreateGiftCards.ftl"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#BulkOperationResult"
            receivePath="${contentRoot}/shopify/GiftCardActivationFeed/result/BulkOperationResult-${systemMessageId}-${remoteMessageId}-${nowDate}.jsonl">
    </moqui.service.message.SystemMessageType>
    ```
4. Import Enumerations
    1. Add enumeration data for relation between BulkCreateGiftCards & GiftCardActivationFeed_{shopId_storeId} SystemMessageType
    - Sample data
    ```xml
    <moqui.basic.Enumeration description="Bulk Create Gift Cards" enumId="BulkCreateGiftCards" enumTypeId="ShopifyMessageTypeEnum" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
    <moqui.basic.Enumeration description="Gift Card Activation Feed" enumId="GiftCardActivationFeed_{shopId_storeId}" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="BulkCreateGiftCards" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
    ```

5. Service Job
    1. Clone the poll_SystemMessageFileSftp_GiftCardActivationFeed Job using the Client Specific Production manuals.