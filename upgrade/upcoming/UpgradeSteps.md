1. Update the instance with the data load command to load the upgrade data only. 
2. Follow the "Upgrade Steps" added below. 
3. Follow the client specific manual if any. 
4. Check the transformations and Nifi flows if configured and requires an update.

## Upgrade Steps
### Poll OMS Order Ids Feed
1. SystemMessageType for OrderIdsFeed
   1. Add shop specific SystemMessageType data taking reference from the template OrderIdsFeed SystemMessageType.
   2. Check and update the receiveFilePattern as required based on the shopId alone or combination of shop Id and product Store Id.
      - Sample data
      - NOTE: add the value for parameterValue and systemMessageRemoteId as per new setup.
        ```xml
        <moqui.service.message.SystemMessageType systemMessageTypeId="OrderIdsFeed_{shopId_storeId}"
                description="Create Order Ids Feed System Message"
                parentTypeId="LocalFeedFile"
                consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#OrderIdsFeed"
                receiveFilePattern=".*{shop_id/store_id}.*.json"
                receivePath="/home/${sftpUsername}/hotwax/shopify/CreatedOrderIdsFeed"
                receiveResponseEnumId="MsgRrMove"
                receiveMovePath="/home/${sftpUsername}/hotwax/shopify/CreatedOrderIdsFeed/archive"
                sendPath="${contentRoot}/shopify/OrderIdsFeed">
            <parameters parameterName="consumeSmrId" parameterValue="{shopify_remote}" systemMessageRemoteId="{remote_sftp}"/>
        </moqui.service.message.SystemMessageType>
        ```

2. SystemMessageType for GenerateOrderMetafieldsFeed
    1. Add shop specific SystemMessageType data taking reference from the template OrderIdsFeed SystemMessageType.
    2. Check and update the receiveFilePattern as required based on the shopId alone or combination of shop Id and product Store Id.
    3. Namespaces can have comma separated values as per requirement.  
       - Sample data
       - NOTE: add the value for parameterValue and systemMessageRemoteId as per new setup.
        ```xml
        <moqui.service.message.SystemMessageType systemMessageTypeId="GenerateOrderMetafieldsFeed_{shopId_storeId}"
                    description="Generate Order Metafields Feed For Orders Feed"
                    sendServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.generate#OrderMetafieldsFeed"
                    sendPath="${contentRoot}/shopify/OrderMetafieldsFeed/OrderMetafieldsFeed-${dateTime}.json">
                <parameters parameterName="namespaces" parameterValue="HotwaxOrderDetails" systemMessageRemoteId="{shopify_remote}"/>
                <parameters parameterName="consumeSmrId" parameterValue="{remote_sftp}" systemMessageRemoteId="{shopify_remote}"/>
        </moqui.service.message.SystemMessageType>
        ```

 
3. SystemMessageType for SendOrderMetafieldsFeed
    ```xml
    <moqui.service.message.SystemMessageType systemMessageTypeId="SendOrderMetafieldsFeed"
            description="Send Order Metafields Feed"
            parentTypeId="LocalFeedFile"
            sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
            sendPath="/home/${sftpUsername}/hotwax/shopify/OrdersMetaFieldsFeed"/>
    ```

4. Enumeration
    1. Add enumeration data for relation between OrderIdsFeed, GenerateOrderMetafieldsFeed and SendOrderMetafieldsFeed SystemMessageType
     - Sample data
        ```xml
        <moqui.basic.Enumeration description="Send Order Metafields Feed" enumId="SendOrderMetafieldsFeed" enumTypeId="ShopifyMessageTypeEnum"/>
        <moqui.basic.Enumeration description="Generate Order Metafields Feed" enumId="GenerateOrderMetafieldsFeed_{shopId_storeId}" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendOrderMetafieldsFeed" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
        <moqui.basic.Enumeration description="Order Ids Feed" enumId="OrderIdsFeed_{shopId_storeId}" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="GenerateOrderMetafieldsFeed_{shopId_storeId}" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
        ```

5. Service Job
   1. Clone the poll_SystemMessageFileSftp_OMSOrderIdsFeed Job using the Client Specific Production manuals.
