## Upgrade Steps
1. Generic Steps for Upgrade data
    1. Pause the Service Jobs scheduled for the feeds if required for the upgrade.
    2. Update the instance with the data load command to load the upgrade data only.
    3. Follow the client specific manual if any.
    4. Check the Nifi flows if configured.

### Poll OMS Fulfillment Feed
1. Pause the jobs which are set up from the template poll_SystemMessageFileSftp_OMSFulfillmentFeed job eg. the jobs set up with job name pattern as  poll_OMSFulfillmentFeed_{store_id/shop_id}.
2. Delete the parameter consumeSmrId from the poll oms fulfillment jobs scheduled for brands.
   - SQL query to delete the parameter from the poll oms fulfillment jobs, both the template job and the scheduled jobs.
   - Sample SQL Query
    ```sql
   delete from service_job_paramter where job_name = 'poll_SystemMessageFileSftp_OMSFulfillmentFeed' and parameter_name = 'consumeSmrId'
   ```
   
3. The System Message Parameter data for OMSFulfillmentFeed SystemMessageType will be loaded as part of upgrade data.
4. For brand specific system message types with the pattern name as OMSFulfillmentFeed_{{store_id/shop_id}}, data for System Message Parameter needs to be added manually.
   - Sample data
    ```xml
   <moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="OMSFulfillmentFeed_STORE_A" parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
   ```

### Poll OMS Synced Refunds Feed
1. Pause the jobs which are set up from the template poll_SystemMessageFileSftp_OMSSyncedRefundsFeed job eg. the jobs set up with job name pattern as poll_OMSSyncedRefundsFeed_{store_id/shop_id}.
2. Delete the parameter consumeSmrId from the poll oms Synced refunds jobs scheduled for brands.
   - SQL query to delete the parameter from the poll oms Synced refunds jobs, both the template job and the scheduled jobs.
   - Sample SQL Query
    ```sql
   delete from service_job_paramter where job_name = 'poll_SystemMessageFileSftp_OMSSyncedRefundsFeed' and parameter_name = 'consumeSmrId'
   ```
3. Add value for parameter receiveFilePattern to OMSSyncedRefundsFeed_{store_id/shop_id} SystemMesagetype to be used in poll service job to pick only those files with a certain store/shop.
4. Update the value of receivePath of SendShopifyReturnReasonFeed_{store_id/shop_id} SystemMesagetype to have store id/shop id in the filename to prepare files store/shop wise.