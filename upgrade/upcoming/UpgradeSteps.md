## Upgrade Steps
1. Generic Steps for Upgrade data
    1. Pause the Service Jobs scheduled for the feeds if required for the upgrade.
    2. Update the instance with the data load command to load the upgrade data only.
    3. Follow the client specific manual if any.
    4. Check the Nifi flows if configured.

### Poll OMS Fulfillment Feed
1. Delete the parameter consumeSmrId from the poll oms fulfillment jobs scheduled for brands.
   - SQL query to delete the parameter from the poll oms fulfillment jobs, both the template job and the scheduled jobs.
   - Sample SQL Query
    ```sql
   delete from service_job_paramter where job_name = 'poll_SystemMessageFileSftp_OMSFulfillmentFeed' and parameter_name = 'consumeSmrId'
   ```
   
2. The System Message Parameter data for OMSFulfillmentFeed SystemMessageType will be loaded as part of upgrade data.
3. For brand specific system message types, data for System Message Parameter needs to be added manually.
   - Sample data
    ```xml
   <moqui.service.message.SystemMessageTypeParameter systemMessageTypeId="OMSFulfillmentFeed_STORE_A" parameterName="consumeSmrId" parameterValue="" systemMessageRemoteId=""/>
   ```
   