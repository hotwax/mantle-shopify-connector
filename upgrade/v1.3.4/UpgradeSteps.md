# Order Rest Json Feed Filtered by Tags
1. Configure remote SFTP server against your shopify config for sending the feed.
    ```xml
   <moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="GenerateOrderRestJsonFeed"
            parameterName="sendSmrId"
            parameterValue=""
            systemMessageRemoteId=""/>
   ```
2. Configure tagsToAdd against your shopify config for the tags to be added to exported orders.
    ```xml
    <moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="GenerateOrderRestJsonFeed"
            parameterName="tagsToAdd"
            parameterValue=""
            systemMessageRemoteId=""/>
    ```
3. Configure SFTP file path in sendPath attribute.
    ```xml
    <moqui.service.message.SystemMessageType systemMessageTypeId="SendOrderRestJsonFeed"
            description="Send Order Json Rest Feed"
            parentTypeId="LocalFeedFile"
            sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
            sendPath="">
    </moqui.service.message.SystemMessageType>
    ```
4. Schedule service job *queue_OrderIdsByTagFeed* with necessary parameter - *systemMessageRemoteId, tag, tagNot*.
