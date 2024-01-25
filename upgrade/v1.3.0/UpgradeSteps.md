1. Update the instance with the data load command to load the upgrade data only.
2. Follow the "Upgrade Steps" added below.
3. Follow the client specific manual if any.
4. Check the transformations and Nifi flows if configured and requires an update.

## Upgrade Steps
### Poll OMS Fulfillment Feed
1. Pause the jobs which are set up from the template poll_SystemMessageFileSftp_OMSFulfillmentFeed job eg. the jobs set up with job name pattern as  poll_OMSFulfillmentFeed_{brand/shop}.
2. Remove the parameter consumeSmrId from the the template job.
    1. Use the below SQL query to delete the parameter from the template job or remove it from the webtools UI.
    ```sql
       delete from service_job_paramter where job_name = 'poll_SystemMessageFileSftp_OMSFulfillmentFeed' 
           and parameter_name = 'consumeSmrId';
    ```
3. Remove this parameter from all client specific feed Service Jobs created from the template poll_SystemMessageFileSftp_OMSFulfillmentFeed Service Job. Use the above SQL by updating the job_name of client specific jobs.
4. The new SystemMessageTypeParameter for OMSFulfillmentFeed SystemMessageType will be loaded as part of upgrade data.
5. Add this parameter to all the System Message Types set up for client specific Service Jobs created from the template poll_SystemMessageFileSftp_OMSFulfillmentFeed Service Job.
   - Sample data
   - NOTE Update for the required systemMessageTypeId by adding values for parameterValue and systemMessageRemoteId fields.
    ```xml
   <moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="OMSFulfillmentFeed" 
          parameterName="consumeSmrId" parameterValue="SHOP_CONFIG" systemMessageRemoteId="RemoteSftp"/>
   ```   
7. If the new instance requires the Poll OMS FUlfillment Feed Jobs to be set up per shop, then add the data for the SystemMessageType of the pattern OMSFulfillmentFeed_{shopId_productStoreId} taking reference from the template of OMSFulfillmentFeed SystemMessageType.
   - Sample data
   - NOTE check and update the receiveFilePattern as required based on the shopId alone or combination of shop Id and product Store Id.
   ```xml
      <moqui.service.message.SystemMessageType systemMessageTypeId="OMSFulfillmentFeed_{shopId_storeId}"
            description="Create OMS Fulfillment Feed System Message"
            parentTypeId="LocalFeedFile"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#FulfillmentFeed"
            receivePath="/home/${sftpUsername}/hotwax/shopify/FulfilledOrderItems"
            receiveResponseEnumId="MsgRrMove"
            receiveMovePath="/home/${sftpUsername}/hotwax/shopify/FulfilledOrderItems/archive"
            sendPath="${contentRoot}/shopify/OMSFulfillmentFeed"
            receiveFilePattern=".*{shop_id/store_id}.*.json">
        <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>
   ```
   
### Poll OMS Synced Refunds Feed
1.Remove the parameter consumeSmrId from the the template poll_SystemMessageFileSftp_OMSSyncedRefundsFeed job.
    1. Use the below SQL query to delete the parameter from the template job or remove it from the webtools UI.
    ```sql
      delete from service_job_paramter where job_name = 'poll_SystemMessageFileSftp_OMSSyncedRefundsFeed' and parameter_name = 'consumeSmrId';
    ```
2. Remove this parameter from all client specific feed Service Jobs created from the template poll_SystemMessageFileSftp_OMSSyncedRefundsFeed Service Job. Use the above SQL by updating the job_name of client specific jobs.
3. NOTE If the new instance requires the Poll OMS Synced Refund Jobs to be set up per shop, then create new data for SystemMessageType and Enumeration; also clone the template ServiceJob to create shop specific service jobs.
    1. SystemMessageType for OMSSyncedRefundsFeed
        1. Add shop specific SystemMessageType data taking reference from the template OMSSyncedRefundsFeed SystemMessageType.
        2. Check and update the receiveFilePattern as required based on the shopId alone or combination of shop Id and product Store Id.
           - Sample data
           - NOTE add the value for parameterValue and systemMessageRemoteId as per new setup.
           ```xml
              <moqui.service.message.SystemMessageType systemMessageTypeId="OMSSyncedRefundsFeed_{shopId_storeId}"
                    description="Create OMS Synced Refunds Feed System Message"
                    parentTypeId="LocalFeedFile"
                    consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#SyncedRefundsFeed"
                    receivePath="/home/${sftpUsername}/hotwax/shopify/SyncedRefundsFeed"
                    receiveResponseEnumId="MsgRrMove"
                    receiveMovePath="/home/${sftpUsername}/hotwax/shopify/SyncedRefundsFeed/archive"
                    sendPath="${contentRoot}/shopify/SyncedRefundsFeed"
                    receiveFilePattern=".*{shop_id/store_id}.*.json">
                <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
              </moqui.service.message.SystemMessageType>
           ```
   2. SystemMessageType for SendShopifyReturnReasonFeed
       1. Add shop specific SystemMessageType data taking reference from the template SendShopifyReturnReasonFeed SystemMessageType.
       2. Update value for field receivePath in the SystemMessageType to create filename particular for a store_id and/or shop_id.
           - Sample data
           ```xml
              <moqui.service.message.SystemMessageType systemMessageTypeId="SendShopifyReturnReasonFeed_{shopId_storeId}"
                    description="Send Shopify Return Reason Feed"
                    parentTypeId="LocalFeedFile"
                    sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
                    sendPath="/home/${sftpUsername}/hotwax/shopify/ShopifyReturnReasonFeed/"
                    receivePath="${contentRoot}/shopify/ShopifyReturnReasonFeed/{shopId_storeId}_ShopifyReturnReasonFeed-${dateTime}.json">
              </moqui.service.message.SystemMessageType>
           ```

    3. Enumeration 
        1. Add enumeration data for SystemMessageTypes OMSSyncedRefundsFeed_{shopId_storeId} and SendShopifyReturnReasonFeed_{shopId_storeId} and link both enumerations using relatedEnumId.
           - Sample data
           ```xml
              <moqui.basic.Enumeration description="Send Shopify Return Reason Feed for {store_id and/or shop_id}" enumId="SendShopifyReturnReasonFeed_{shopId_storeId}" enumTypeId="ShopifyMessageTypeEnum"/>
              <moqui.basic.Enumeration description="OMS Synced Refunds Feed for {store_id and/or shop_id}" enumId="OMSSyncedRefundsFeed_{shopId_storeId}" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendShopifyReturnReasonFeed_{shopId_storeId}" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
           ```

    4. Service Job 
        1. Clone the poll_SystemMessageFileSftp_OMSSyncedRefundsFeed Job using the Client Specific Production manuals.
