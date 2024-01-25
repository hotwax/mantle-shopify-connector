## Upgrade Steps
1. Generic Steps for Upgrade data
    1. Pause the Service Jobs scheduled for the feeds if required for the upgrade.
    2. Update the instance with the data load command to load the upgrade data only.
    3. Follow the client specific manual if any.
    4. Check the Nifi flows if configured.

### Poll OMS Fulfillment Feed
1. Pause the jobs which are set up from the template poll_SystemMessageFileSftp_OMSFulfillmentFeed job eg. the jobs set up with job name pattern as  poll_OMSFulfillmentFeed_{BrandName}.
2. Delete the parameter consumeSmrId from the poll oms fulfillment jobs scheduled for brands.
   - SQL query to delete the parameter from the poll oms fulfillment jobs, both the template job and the scheduled jobs.
   - Sample SQL Query
    ```sql
       delete from service_job_paramter where job_name = 'poll_SystemMessageFileSftp_OMSFulfillmentFeed' 
           and parameter_name = 'consumeSmrId'
    ```

3. The System Message Parameter data for OMSFulfillmentFeed SystemMessageType will be loaded as part of upgrade data.
4. System Message Parameter needs to be added manually.
   - Sample data
    ```xml
   <moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="OMSFulfillmentFeed" 
          parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
   ```

   NOTE: If feeds are set according to store and shop specific to client then we need to create new data for SystemMessageTypes.
5. Add the SystemMessageType OMSFulfillmentFeed_{store_id & shop_id} from the template of OMSFulfillmentFeed SystemMessageType.
   - Sample data
   ```xml
      <moqui.service.message.SystemMessageType systemMessageTypeId="OMSFulfillmentFeed_{store_id & shop_id}"
            description="Create OMS Fulfillment Feed System Message"
            parentTypeId="LocalFeedFile"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#FulfillmentFeed"
            receivePath="/home/${sftpUsername}/hotwax/shopify/FulfilledOrderItems"
            receiveResponseEnumId="MsgRrMove"
            receiveMovePath="/home/${sftpUsername}/hotwax/shopify/FulfilledOrderItems/archive"
            sendPath="${contentRoot}/shopify/OMSFulfillmentFeed"
            receiveFilePattern=".*{store_id & shop_id}.*.json">
        <parameters parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
    </moqui.service.message.SystemMessageType>
   ```
   
### Poll OMS Synced Refunds Feed
1. Delete the parameter consumeSmrId from the poll_SystemMessageFileSftp_OMSSyncedRefundsFeed template job.
   - SQL query to delete the parameter from the poll_SystemMessageFileSftp_OMSSyncedRefundsFeed template job.
   - Sample SQL Query
    ```sql
      delete from service_job_paramter where job_name = 'poll_SystemMessageFileSftp_OMSSyncedRefundsFeed' and parameter_name = 'consumeSmrId'
    ```

   NOTE: If feeds are set according to store and shop specific to client then we need to create new data for SystemMessageTypes, Enumeration data and service jobs. 
2. Add the SystemMessageType OMSSyncedRefundsFeed_{store_id & shop_id} from the template of OMSSyncedRefundsFeed SystemMessageType.
   - Add value for parameter receiveFilePattern in the SystemMessageType to receive only those particular to a store_id & shop_id.
   - Sample data
   ```xml
      <moqui.service.message.SystemMessageType systemMessageTypeId="OMSSyncedRefundsFeed_{store_id & shop_id}"
            description="Create OMS Synced Refunds Feed System Message for FAO CA_SHOP"
            parentTypeId="LocalFeedFile"
            consumeServiceName="co.hotwax.shopify.system.ShopifySystemMessageServices.consume#SyncedRefundsFeed"
            receivePath="/home/${sftpUsername}/hotwax/shopify/SyncedRefundsFeed"
            receiveResponseEnumId="MsgRrMove"
            receiveMovePath="/home/${sftpUsername}/hotwax/shopify/SyncedRefundsFeed/archive"
            sendPath="${contentRoot}/shopify/SyncedRefundsFeed"
            receiveFilePattern=".*{store_id & shop_id}.*.json">
      </moqui.service.message.SystemMessageType>
   ```

3. Add the SystemMessageType SendShopifyReturnReasonFeed_{store_id & shop_id} from the template of SendShopifyReturnReasonFeed SystemMessageType.
   - Update value for parameter receivePath in the SystemMessageType to create filename particular of a store_id & shop_id.
   - Sample data
   ```xml
      <moqui.service.message.SystemMessageType systemMessageTypeId="SendShopifyReturnReasonFeed{store_id & shop_id}"
            description="Send Shopify Return Reason Feed for FAO CA_SHOP"
            parentTypeId="LocalFeedFile"
            sendServiceName="co.hotwax.ofbiz.SystemMessageServices.send#SystemMessageFileSftp"
            sendPath="/home/${sftpUsername}/hotwax/shopify/ShopifyReturnReasonFeed/"
            receivePath="${contentRoot}/shopify/ShopifyReturnReasonFeed/{store_id & shop_id}_ShopifyReturnReasonFeed-${dateTime}.json">
      </moqui.service.message.SystemMessageType>
   ```

4. Add enumeration data for SystemMessageTypes OMSSyncedRefundsFeed_{store_id & shop_id} and SendShopifyReturnReasonFeed_{store_id & shop_id}.
   - Sample data
   ```xml
      <moqui.basic.Enumeration description="Send Shopify Return Reason Feed for {store_id & shop_id}" enumId="SendShopifyReturnReasonFeed_{store_id & shop_id}" enumTypeId="ShopifyMessageTypeEnum"/>
      <moqui.basic.Enumeration description="OMS Synced Refunds Feed for {store_id & shop_id}" enumId="OMSSyncedRefundsFeed_{store_id & shop_id}" enumTypeId="ShopifyMessageTypeEnum" relatedEnumId="SendShopifyReturnReasonFeed_{store_id & shop_id}" relatedEnumTypeId="ShopifyMessageTypeEnum"/>
   ```

5. Add jobs poll_OMSSyncedRefundsFeed_{store_id & shop_id} as per the store_id & shop_id from the template job poll_SystemMessageFileSftp_OMSSyncedRefundsFeed. 
   - Set its SystemMessageType as OMSSyncedRefundsFeed_{store_id & shop_id}.